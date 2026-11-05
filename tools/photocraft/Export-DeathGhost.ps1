# Normalize the supplied four-frame ghost with PhotoCraft; preserve original.
$ErrorActionPreference='Stop'
$invoke=Join-Path $PSScriptRoot 'Invoke-PhotoCraft.ps1'
$root=Split-Path (Split-Path $PSScriptRoot -Parent) -Parent
$source=Join-Path $root 'assets/sprites/Ghost Orb Idle Animation Sprite Sheet.png'
$out=Join-Path $root 'assets/sprites/death-ghost.png'
if(Test-Path -LiteralPath $out){throw 'Output exists; preserve it or choose a new output filename.'}
$work=Join-Path $root 'build/death-ghost-photocraft'
New-Item -ItemType Directory -Force -Path $work | Out-Null
$steps=New-Object 'System.Collections.Generic.List[string]'
for($i=0;$i -lt 4;$i++){
 $frame=Join-Path $work "frame-$i.png"
 $crop=@{x=($i*543);y=0;width=543;height=724}|ConvertTo-Json -Compress
 $size=@{width=192;height=256;resample='nearest'}|ConvertTo-Json -Compress
 $pad=@{width=256;height=256;anchor='center';extensionColor='transparent'}|ConvertTo-Json -Compress
 & $invoke -CliArgs @('run',$source,'--cmd','image.crop','--params',$crop,'--cmd','image.imageSize','--params',$size,'--cmd','image.canvasSize','--params',$pad,'--out',$frame)|Out-Null
 if($LASTEXITCODE -ne 0){throw "Failed frame $i"}
 $place=@{path=$frame;scale=100;fit=$false;smartObject=$false;center=@(($i*256+128),128)}|ConvertTo-Json -Compress
 $steps.Add('--cmd');$steps.Add('file.placeEmbedded');$steps.Add('--params');$steps.Add($place)
}
$new=@{width=1024;height=256;background='transparent';mode='rgb';depth=8}|ConvertTo-Json -Compress
& $invoke -CliArgs (@('run','--new',$new)+$steps.ToArray()+@('--out',$out))|Out-Null
if($LASTEXITCODE -ne 0){throw 'Could not assemble ghost sheet'}
