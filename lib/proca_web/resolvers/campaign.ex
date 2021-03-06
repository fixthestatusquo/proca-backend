defmodule ProcaWeb.Resolvers.Campaign do
  @moduledoc """
  Resolvers for campaign queries in mutations
  """
  import Ecto.Query
  alias Proca.Repo
  alias Proca.{Campaign, ActionPage, Staffer, Org}
  import Proca.Staffer.Permission
  alias ProcaWeb.Helper
  alias Proca.Server.Notify

  def list(_, %{id: id}, _) do
    cl =
      list_query()
      |> where([x], x.id == ^id)
      |> Proca.Repo.all()

    {:ok, cl}
  end

  def list(_, %{name: name}, _) do
    cl =
      list_query()
      |> where([x], x.name == ^name)
      |> Proca.Repo.all()

    {:ok, cl}
  end

  def list(_, %{title: title}, _) do
    cl =
      list_query()
      |> where([x], like(x.title, ^title))
      |> Proca.Repo.all()

    {:ok, cl}
  end

  def list(_, _, _) do
    cl = Proca.Repo.all(list_query())
    {:ok, cl}
  end

  defp list_query() do
    from(x in Proca.Campaign, preload: [:org])
  end

  def stats(campaign, _a, _c) do
    %Proca.Server.Stats{
      supporters: supporters, 
      action: at_cts, 
      area: supporters_by_areas,
      org: supporter_count_by_org
      } = Proca.Server.Stats.stats(campaign.id)

    {:ok,
     %{
       supporter_count: supporters,
       supporter_count_by_area: supporters_by_areas |> Enum.map(fn {area, ct} -> %{area: area, count: ct} end),
       supporter_count_by_org: supporter_count_by_org,
       action_count: at_cts |> Enum.map(fn {at, ct} -> %{action_type: at, count: ct} end),
     }}
  end

  def org_stats(%{supporter_count_by_org: org_st}, _, _) do 
    org_ids = Map.keys(org_st)

    with_names = 
    from(o in Org, where: o.id in ^org_ids, select: {o.id, o.name, o.title})
    |> Repo.all()
    |> Enum.map(fn {id, name, title} -> 
      %{
        org: %{ name: name, title: title },
        count: org_st[id]
      }
    end)

    {:ok, with_names}
  end

  def org_stats_others(par, %{org_name: org_name}, ctx) do 
    {:ok, by_names} = org_stats(par, %{}, ctx)

    {:ok, 
      by_names 
      |> Enum.filter(fn %{org: %{name: name}} -> name != org_name end)
      |> Enum.map(fn %{count: count} -> count end)
      |> Enum.sum()
    }
  end 

  @doc "XXX deprecated in favor of upsert/3"
  def declare_upsert(p, attrs, res) do
    upsert(p, %{input: attrs}, res)
  end

  def upsert(_, %{input: attrs = %{action_pages: pages}}, %{context: %{org: org}}) do
    # XXX Add name: attributes if url given (Legacy for declare_campaign)
    pages =
      Enum.map(pages, fn ap ->
        case ap do
          %{url: url} -> Map.put(ap, :name, url)
          ap -> ap
        end
      end)

    result = Repo.transaction(fn ->
      campaign = upsert_campaign(org, attrs)
      pages
      |> Enum.map(&fix_page_legacy_url/1)
      |> Enum.each(fn page ->
        ap = upsert_action_page(org, campaign, page)
        Notify.action_page_updated(ap)
        ap
      end)

      campaign
    end)

    case result do
      {:ok, _} = r -> r
      {:error, invalid} -> {:error, Helper.format_errors(invalid)}
    end
  end

  # XXX for declareCampaign support
  defp fix_page_legacy_url(page = %{url: url}) do
    case url do
      "https://" <> n -> %{page | name: n}
      "http://" <> n -> %{page | name: n}
      n -> %{page | name: n}
    end
    |> Map.delete(:url)
  end

  defp fix_page_legacy_url(page), do: page

  def upsert_campaign(org, attrs) do
    campaign = Campaign.upsert(org, attrs)

    if not campaign.valid? do
      Repo.rollback(campaign)
    end

    if campaign.data.id do
      Repo.update!(campaign)
    else
      Repo.insert!(campaign)
    end
  end

  def upsert_action_page(org, campaign, attrs) do
    ap = ActionPage.upsert(org, campaign, attrs)

    if not ap.valid? do
      Repo.rollback(ap)
    end

    if ap.data.id do
      Repo.update!(ap)
    else
      Repo.insert!(ap)
    end
  end
end
