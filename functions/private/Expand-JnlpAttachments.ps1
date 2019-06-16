<#
.SYNOPSIS
 Extracts attachments from a JNLP file.

.PARAMETER Path
 Path to the JNLP file to search for attachments.

.PARAMETER Destination
 Path to destination directory.

#>
function Expand-JnlpAttachments {

    param(

        [Parameter(Mandatory)]
        [ValidatePattern('\.jnlp$')]
        $Path

    )

    $Path = [System.IO.FileInfo][string]( Resolve-Path $Path )

    Get-Content $Path -Raw |
        ForEach-Object { ([xml]$_).jnlp.'application-desc'.argument } |
        Where-Object { $_ -match 'JNLP_ATTACHMENTS' } |
        ForEach-Object { $_.Split('=',2)[1].Split(';') } |
        Select-Object @{N='Path';E={ Join-Path $Path.Directory.FullName $_.Split(',',2)[0] }}, @{N='Base64Data';E={ $_.Split(':',2)[1] }} |
        ForEach-Object {
            $DecodedData = [System.Convert]::FromBase64String( $_.Base64Data )
            $MemoryStream = New-Object System.IO.MemoryStream ( , $DecodedData )
            $DeflateStream = New-Object System.IO.Compression.DeflateStream ( $MemoryStream, [System.IO.Compression.CompressionMode]::Decompress )
            $ByteList = New-Object collections.generic.list[byte]
            while ( ( $Byte = $DeflateStream.ReadByte() ) -ne -1 ) { $ByteList.Add( $Byte) }
            Set-Content -Encoding Byte -Value $ByteList.ToArray() -Path $_.Path
        }

}
