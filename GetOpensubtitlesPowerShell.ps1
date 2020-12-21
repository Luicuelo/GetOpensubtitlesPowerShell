$dataLength = 65536

function LongSum([UInt64]$a, [UInt64]$b) { 
	[UInt64](([Decimal]$a + $b) % ([Decimal]([UInt64]::MaxValue) + 1)) 
}

function StreamHash([IO.Stream]$stream) {
	$hashLength = 8
	[UInt64]$lhash = 0
	[byte[]]$buffer = New-Object byte[] $hashLength
	$i = 0
	while ( ($i -lt ($dataLength / $hashLength)) -and ($stream.Read($buffer,0,$hashLength) -gt 0) ) {
		$i++
		$lhash = LongSum $lhash ([BitConverter]::ToUInt64($buffer,0))
	}
	$lhash
}

function MovieHash([string]$path) {
	try { 
		$stream = [IO.File]::OpenRead($path) 
		[UInt64]$lhash = $stream.Length
		$lhash = LongSum $lhash (StreamHash $stream)
		$stream.Position = [Math]::Max(0L, $stream.Length - $dataLength)
		$lhash = LongSum $lhash (StreamHash $stream)
		"{0:X}" -f $lhash
	}
	finally { $stream.Close() }
}

function formatString([string]$s , [int]$n) {
    $l=$n-$s.Length
    $spaces = ' ' * $l
    [string]$sal=$s+$spaces  
    return $sal;
}

$filename="C:\temp\FileName.mp4"
$hash=MovieHash $filename 
$size=(Get-Item $filename).length.ToString()

$api='https://api.opensubtitles.org/xml-rpc'

$user='xxxx'
$pass='*****'
$language='es'


$slogin='<?xml version="1.0"?>
<methodCall>
<methodName>LogIn</methodName>
<params>
<param><value><string>'+$user+'</string></value></param>
<param><value><string>'+$pass+'</string></value></param>
<param><value><string>'+$language+'</string></value></param>
<param><value><string>home media viewer v1.0</string></value></param>
</params>
</methodCall>'



$response=Invoke-WebRequest -UseBasicParsing $api -ContentType "text/xml" -Method POST -Body $slogin


[System.Xml.XmlDocument]$xml = new-object System.Xml.XmlDocument
$xml.InnerXml=$response.Content
$token=($xml.SelectNodes("/methodResponse/params/param/value/struct/member[name='token']").value.string)
$status=($xml.SelectNodes("/methodResponse/params/param/value/struct/member[name='status']").value.string)
$status




$search='<?xml version="1.0"?>
<methodCall>
 <methodName>SearchSubtitles</methodName>
 <params>
  <param>
   <value><string>'+$token+'</string></value>
  </param>
  <param>
   <value>
    <array>
     <data>
      <value>
       <struct>
        <member>
         <name>sublanguageid</name>
         <value><string>es,eng</string>
         </value>
        </member>
        <member>
         <name>moviehash</name>
         <value><string>'+$hash+'</string></value>
        </member>
        <member>
         <name>moviebytesize</name>
         <value><double>'+$size+'</double></value>
        </member>
       </struct>
      </value>
     </data>
    </array>
   </value>
  </param>
 </params>
</methodCall>'


$responseSearch=Invoke-WebRequest -UseBasicParsing $api -ContentType "text/xml" -Method POST -Body $search

$logout='<?xml version="1.0"?>
<methodCall>
 <methodName>LogOut</methodName>
 <params>
  <param>
   <value><string>'+$token+'</string></value>
  </param>
 </params>
</methodCall>'

$response=Invoke-WebRequest -UseBasicParsing $api -ContentType "text/xml" -Method POST -Body $logout

[System.Xml.XmlDocument]$xmlSearch = new-object System.Xml.XmlDocument
$xmlSearch.InnerXml=$responseSearch.Content
$status=($xmlSearch.SelectNodes("/methodResponse/params/param/value/struct/member[name='status']").value.string)
$arrayDatos=($xmlSearch.SelectNodes("/methodResponse/params/param/value/struct/member[name='data']").value)


foreach ($data in $arrayDatos.array.data){
        "---------------------------------------------------------------------------------"
        foreach ($member in  $data.value.struct.member){
             $fs = formatString ($member.name+":") 20
             $fs + $member.value.string
        }
}