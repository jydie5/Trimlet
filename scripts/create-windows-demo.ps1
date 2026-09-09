[CmdletBinding()]
param([string]$OutputDirectory = (Join-Path $env:TEMP 'trimlet-demo'))
$ErrorActionPreference = 'Stop'
New-Item -ItemType Directory -Path $OutputDirectory -Force | Out-Null
$output = Join-Path $OutputDirectory 'Color study.mp4'
# Original procedural imagery: no third-party footage, music, or user paths.
& ffmpeg -hide_banner -loglevel error -y -f lavfi -i 'gradients=s=1280x720:r=30:c0=0x09283c:c1=0x32d6b0:c2=0xffca81:n=3:t=spiral:speed=0.015:seed=24:d=30' -f lavfi -i 'sine=frequency=220:sample_rate=48000:duration=30' -vf "drawtext=fontfile='C\:/Windows/Fonts/segoeui.ttf':text='COLOR STUDY':fontsize=58:fontcolor=white:x=70:y=510,drawtext=fontfile='C\:/Windows/Fonts/segoeui.ttf':text='Motion / Light / Rhythm':fontsize=24:fontcolor=white@0.85:x=73:y=588" -c:v libx264 -preset fast -crf 20 -pix_fmt yuv420p -c:a aac -af volume=0.03 -shortest $output
if ($LASTEXITCODE -ne 0) { throw 'Demo generation failed.' }
Write-Output $output
