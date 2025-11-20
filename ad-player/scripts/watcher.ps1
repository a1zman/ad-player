$Folder = "C:\Users\genil\Videos\Captures"
$VlcPath = "C:\Program Files\VideoLAN\VLC\vlc.exe"

$VlcArgsBase = @(
    "--fullscreen",
    "--no-video-title-show",
    "--qt-fullscreen-screennumber=1",
    '--directx-device=\\.\DISPLAY2',
    "--repeat"
)

$LoopSleepSeconds = 2
$StableChecks = 3
$StableDelaySeconds = 1

if (!(Test-Path $VlcPath)) {
    exit 1
}

Add-Type -AssemblyName System.Windows.Forms

Add-Type @"
using System;
using System.Runtime.InteropServices;
public class Win32 {
  [DllImport("user32.dll")]
  public static extern bool SetCursorPos(int X, int Y);
}
"@

function Get-NewestMp4 {
    param($folderPath)
    Get-ChildItem -Path $folderPath -Filter *.mp4 -File -ErrorAction SilentlyContinue |
      Sort-Object LastWriteTime -Descending |
      Select-Object -First 1
}

function Wait-UntilFileStable {
    param($filePath, $checks, $delay)
    if (!(Test-Path $filePath)) { return $false }
    $prevSize = (Get-Item $filePath).Length
    for ($i=0; $i -lt $checks; $i++) {
        Start-Sleep -Seconds $delay
        if (!(Test-Path $filePath)) { return $false }
        $size = (Get-Item $filePath).Length
        if ($size -eq $prevSize) { return $true } else { $prevSize = $size }
    }
    while ($true) {
        Start-Sleep -Seconds $delay
        if (!(Test-Path $filePath)) { return $false }
        $size2 = (Get-Item $filePath).Length
        if ($size2 -eq $prevSize) { return $true }
        $prevSize = $size2
    }
}

$currentFile = $null

while ($true) {

    try {
        $newest = Get-NewestMp4 -folderPath $Folder
    } catch {
        $newest = $null
    }

    if ($null -ne $newest) {
        $newPath = $newest.FullName
        if ($newPath -ne $currentFile) {
            $stable = Wait-UntilFileStable -filePath $newPath -checks $StableChecks -delay $StableDelaySeconds
            if ($stable) {
                Get-Process -Name vlc -ErrorAction SilentlyContinue | ForEach-Object {
                    try { Stop-Process -Id $_.Id -Force -ErrorAction SilentlyContinue } catch {}
                }

                Start-Sleep -Milliseconds 400

                $args = @($newPath) + $VlcArgsBase
                Start-Process -FilePath $VlcPath -ArgumentList $args

                $currentFile = $newPath
            }
        }
    } else {
        if ($currentFile -ne $null) {
            Get-Process -Name vlc -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
            $currentFile = $null
        }
    }

    Start-Sleep -Seconds $LoopSleepSeconds
}
