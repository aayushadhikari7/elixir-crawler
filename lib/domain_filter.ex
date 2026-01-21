defmodule Crawler.DomainFilter do
  def same_domain?(url, base_url) do
    get_domain(url) == get_domain(base_url)
  end

  def filter_same_domain(urls, base_url) do
    base_domain = get_domain(base_url)
    Enum.filter(urls, fn url -> get_domain(url) == base_domain end)
  end

  def filter_by_domains(urls, allowed_domains) do
    Enum.filter(urls, fn url ->
      domain = get_domain(url)
      Enum.any?(allowed_domains, &(domain == &1 or String.ends_with?(domain, "." <> &1)))
    end)
  end

  def get_domain(url) do
    case URI.parse(url) do
      %{host: nil} -> ""
      %{host: host} -> host
    end
  end
end
