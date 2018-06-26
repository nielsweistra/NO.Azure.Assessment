class AzureRestServiceManager {

    [guid] $SubscriptionId = "8b32203d-d655-41b1-84a7-2f119b31dc8a"    
    [guid] $TenantId = "b2569ab6-7aa8-43fe-9a2c-e4abeb992e00"
    [guid] $ClientId = "a72ae51b-31a2-4e9a-b1df-bca4778f01ab"
    [string] $ClientSecret
    [string] $Resource = "https://management.core.windows.net/"
    [string] $TokenRequestUri = "https://login.microsoftonline.com/$($this.TenantId)/oauth2/token"
    [PSCustomObject] $Response = $null
    [PSCustomObject] $Token = $null  
    

    AzureRestServiceManager () {
        
    }

    AzureRestServiceManager ($SubscriptionId, $ClientId, $ClientSecret) {
        $this.ClientSecret = $ClientSecret
        $this.SubscriptionId = $SubscriptionId
        $this.ClientId = $ClientId
        
        $body = "grant_type=client_credentials&client_id=$($ClientId)&client_secret=$($ClientSecret)&resource=$($this.Resource)"
        $this.Token = Invoke-RestMethod -Method Post -Uri $this.TokenRequestUri -Body $body -ContentType 'application/x-www-form-urlencoded'

        Write-Verbose "Print Token"
        Write-Verbose $this.Token
    }

    [void] Get ([uri]$ApiUri) {
        $Headers = @{}
        $Headers.Add("Authorization","$($this.Token.token_type) "+ " " + "$($this.Token.access_token)")
        $this.Response = Invoke-RestMethod -Method Get -Uri $ApiUri -Headers $Headers
    }

    [void] Put ([uri]$ApiUri,[string]$body) {
        $contentType = "application/json"  
        $Headers = @{}
        $Headers.Add("Authorization","$($this.Token.token_type) "+ " " + "$($this.Token.access_token)")
        $this.Response = Invoke-RestMethod -Method Put -Uri $ApiUri -Headers $Headers -Body $body -ContentType $contentType
    }
}