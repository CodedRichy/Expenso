$src = "$PSScriptRoot\..\assets\app_icon_revamp.png"
$res = "$PSScriptRoot\..\android\app\src\main\res"

Copy-Item $src "$res\mipmap-mdpi\ic_launcher.png"    -Force
Copy-Item $src "$res\mipmap-hdpi\ic_launcher.png"    -Force
Copy-Item $src "$res\mipmap-xhdpi\ic_launcher.png"   -Force
Copy-Item $src "$res\mipmap-xxhdpi\ic_launcher.png"  -Force
Copy-Item $src "$res\mipmap-xxxhdpi\ic_launcher.png" -Force

Copy-Item $src "$res\drawable-mdpi\ic_launcher_foreground.png"    -Force
Copy-Item $src "$res\drawable-hdpi\ic_launcher_foreground.png"    -Force
Copy-Item $src "$res\drawable-xhdpi\ic_launcher_foreground.png"   -Force
Copy-Item $src "$res\drawable-xxhdpi\ic_launcher_foreground.png"  -Force
Copy-Item $src "$res\drawable-xxxhdpi\ic_launcher_foreground.png" -Force

Write-Host "Done - revamp copied to all Android icon slots."
