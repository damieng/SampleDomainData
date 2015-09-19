# .SYNOPSIS
#   Populates an Elasticsearch server with domain model data.
# .DESCRIPTION
#   This script uploads the given JSON data to an Elasticsearch server.
# .PARAMETER $uri
#   The URI for the Elasticsearch server (i.e., "http://localhost:9200")
# .PARAMETER $index
#   The index to add the documents to. The index must not already exist.
# .PARAMETER $models
#   Names of the JSON models (i.e., "("WebUsers", "JobOpenings")")
# .LINK
#   https://github.com/bradwilson/ElasticLINQDemos

param(
    [Parameter(Mandatory = $true)]
    [string]$uri,
    [Parameter(Mandatory = $true)]
    [string]$index,
    [Parameter(Mandatory = $true)]
    [string[]]$models
)

[Reflection.Assembly]::LoadWithPartialName("System.Net.Http") | Out-Null

if (-not $uri.EndsWith("/")) {
    $uri += "/"
}

$uri += $index + "/"
$utf8 = [Text.Encoding]::UTF8
$httpClient = New-Object 'System.Net.Http.HttpClient'
$jsonMime = "application/json"

Write-Host $("PUT " + $uri)
$content = New-Object 'System.Net.Http.StringContent' ('', $utf8, $jsonMime)
$result = $httpClient.PutAsync($uri, $content).GetAwaiter().GetResult()
if ($result.StatusCode -ne 200) {
	Write-Host $("Failed to create index '" + $index + "' at " + $uri)
	Write-Host $($result.Content.ReadAsStringAsync().Result)
    $result.Dispose() | Out-Null
	exit 1
}
$result.Dispose() | Out-Null

ForEach ($model in $models) {
  Get-ChildItem -Recurse -Filter "*.json" | ForEach-Object {
    $entity = $(Resolve-Path $_.FullName -Relative).Substring(2).Replace("\", "/").Replace(".json", "")
    $indexUri = $uri + ($entity[0].ToString().ToLowerInvariant() + $entity.Substring(1))
    Write-Host $("Populating " + $indexUri)
    $parsedDoc = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    ForEach ($domainDoc in $parsedDoc) {
      $body = ConvertTo-Json $domainDoc -Depth 20
      $docUri = $indexUri + '/' + $domainDoc.id
      $content = New-Object 'System.Net.Http.StringContent' ($body, $utf8, $jsonMime)
      $result = $httpClient.PutAsync($docUri, $content).Result
      $result.EnsureSuccessStatusCode() | Out-Null
      $result.Dispose() | Out-Null
    }
  }
}

$httpClient.Dispose() | Out-Null
