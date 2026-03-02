Add-Type -AssemblyName System.Drawing

$src = "$PSScriptRoot\..\assets\app_icon_revamp.png"
$img = [System.Drawing.Image]::FromFile($src)

function Save-Icon {
    param([string]$path, [int]$size)
    $bmp = New-Object System.Drawing.Bitmap($size, $size)
    $g   = [System.Drawing.Graphics]::FromImage($bmp)
    $g.InterpolationMode = [System.Drawing.Drawing2D.InterpolationMode]::HighQualityBicubic
    $g.SmoothingMode     = [System.Drawing.Drawing2D.SmoothingMode]::HighQuality
    $g.PixelOffsetMode   = [System.Drawing.Drawing2D.PixelOffsetMode]::HighQuality
    $g.DrawImage($img, 0, 0, $size, $size)
    $g.Dispose()
    $bmp.Save($path, [System.Drawing.Imaging.ImageFormat]::Png)
    $bmp.Dispose()
    Write-Host ("Saved {0,4}x{0,-4} -> {1}" -f $size, (Split-Path $path -Leaf))
}

$res = "$PSScriptRoot\..\android\app\src\main\res"
Save-Icon "$res\mipmap-mdpi\ic_launcher.png"    48
Save-Icon "$res\mipmap-hdpi\ic_launcher.png"    72
Save-Icon "$res\mipmap-xhdpi\ic_launcher.png"   96
Save-Icon "$res\mipmap-xxhdpi\ic_launcher.png"  144
Save-Icon "$res\mipmap-xxxhdpi\ic_launcher.png" 192

$ios = "$PSScriptRoot\..\ios\Runner\Assets.xcassets\AppIcon.appiconset"
Save-Icon "$ios\Icon-App-20x20@1x.png"      20
Save-Icon "$ios\Icon-App-20x20@2x.png"      40
Save-Icon "$ios\Icon-App-20x20@3x.png"      60
Save-Icon "$ios\Icon-App-29x29@1x.png"      29
Save-Icon "$ios\Icon-App-29x29@2x.png"      58
Save-Icon "$ios\Icon-App-29x29@3x.png"      87
Save-Icon "$ios\Icon-App-40x40@1x.png"      40
Save-Icon "$ios\Icon-App-40x40@2x.png"      80
Save-Icon "$ios\Icon-App-40x40@3x.png"     120
Save-Icon "$ios\Icon-App-50x50@1x.png"      50
Save-Icon "$ios\Icon-App-50x50@2x.png"     100
Save-Icon "$ios\Icon-App-57x57@1x.png"      57
Save-Icon "$ios\Icon-App-57x57@2x.png"     114
Save-Icon "$ios\Icon-App-60x60@2x.png"     120
Save-Icon "$ios\Icon-App-60x60@3x.png"     180
Save-Icon "$ios\Icon-App-72x72@1x.png"      72
Save-Icon "$ios\Icon-App-72x72@2x.png"     144
Save-Icon "$ios\Icon-App-76x76@1x.png"      76
Save-Icon "$ios\Icon-App-76x76@2x.png"     152
Save-Icon "$ios\Icon-App-83.5x83.5@2x.png" 167
Save-Icon "$ios\Icon-App-1024x1024@1x.png" 1024

$img.Dispose()
Write-Host "`nDone. All icons updated to app_icon_revamp."
