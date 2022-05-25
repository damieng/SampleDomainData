# .SYNOPSIS
#   Populates an Elasticsearch server with domain model data.
# .DESCRIPTION
#   This script uploads the given JSON data to an Elasticsearch server.
# .PARAMETER $uri
#   The URI for the Elasticsearch server (i.e., "http://localhost:9200")
# .PARAMETER $indexPrefix
#   The index prefix for the documents to. The indexes must not already exist.
# .PARAMETER $models
#   Names of the JSON models (i.e., "("WebUsers", "JobOpenings")")
# .PARAMETER $accessKey
#   Optional access key if Elastic instance requires it.
# .PARAMETER $accessSecret
#   Optional access secret if Elastic instance requires it.
# .LINK
#   https://github.com/bradwilson/ElasticLINQDemos

param(
    [Parameter(Mandatory = $true)]
    [string]$uri,
    [Parameter(Mandatory = $true)]
    [string]$indexPrefix,
    [Parameter(Mandatory = $true)]
    [string[]]$models,
    [Parameter(Mandatory = $false)]
    [string]$accessKey,
    [Parameter(Mandatory = $false)]
    [string]$accessSecret
)

[Reflection.Assembly]::LoadWithPartialName("System.Net.Http") | Out-Null

if (-not $uri.EndsWith("/")) {
    $uri += "/"
}

$utf8 = [Text.Encoding]::UTF8
$httpClient = New-Object 'System.Net.Http.HttpClient'
$jsonMime = "application/json"

if ($accessKey) {
  $accessToken = [Convert]::ToBase64String([System.Text.Encoding]::UTF8.GetBytes($accessKey + ":" + $accessSecret))
  $httpClient.DefaultRequestHeaders.Authorization = New-Object System.Net.Http.Headers.AuthenticationHeaderValue("Basic", $accessToken);
}

ForEach ($model in $models) {
  Get-ChildItem -Recurse -Filter "*.json" | ForEach-Object {
    $entity = $(Resolve-Path $_.FullName -Relative).Substring(2).Replace("\", "/").Replace(".json", "")
    $index = ($indexPrefix + $entity).ToLower()
    Write-Host $("Populating " + $index + " at " + $uri)

    # Create Index
    $content = New-Object 'System.Net.Http.StringContent' ('', $utf8, $jsonMime)
    $result = $httpClient.PutAsync($uri + $index, $content).GetAwaiter().GetResult()
    if ($result.StatusCode -ne 200) {
      Write-Host $("Failed to create index '" + $index + "' at " + $uri)
      Write-Host $($result.Content.ReadAsStringAsync().Result)
        $result.Dispose() | Out-Null
      exit 1
    }
    $result.Dispose() | Out-Null

    $parsedDoc = Get-Content $_.FullName -Raw -Encoding UTF8 | ConvertFrom-Json

    ForEach ($domainDoc in $parsedDoc) {
      $body = ConvertTo-Json $domainDoc -Depth 20
      $docUri = $uri + $index + "/" + $entity.ToLower() + "/" + $domainDoc.id
      Write-Host $("Creating doc at " + $docUri)
      $content = New-Object 'System.Net.Http.StringContent' ($body, $utf8, $jsonMime)
      $result = $httpClient.PutAsync($docUri, $content).Result
      $result.EnsureSuccessStatusCode() | Out-Null
      $result.Dispose() | Out-Null
    }
  }
}

$httpClient.Dispose() | Out-Null
