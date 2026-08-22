<#
.SYNOPSIS
    Copia PDFs, slides (.pptx) e notebooks (.ipynb) do repositorio privado para este
    repositorio publico. Nunca copia .md, imagens, nem nada da pasta Interno/.

.DESCRIPTION
    Por padrao atualiza apenas as sessoes que JA existem aqui no repo publico —
    assim uma sessao ainda em revisao nao vaza sem querer.
    Para publicar uma sessao nova, passe -Sessao com o prefixo dela.

.EXAMPLE
    .\sync.ps1
    Atualiza os arquivos das sessoes ja publicadas.

.EXAMPLE
    .\sync.ps1 -Sessao 03
    Publica (ou atualiza) a sessao 03.

.EXAMPLE
    .\sync.ps1 -Sessao 03 -Commit
    Publica a sessao 03 e ja faz commit + push.
#>
[CmdletBinding()]
param(
    # Prefixo da sessao a publicar, ex: "03". Aceita mais de uma: -Sessao 03,04
    [string[]] $Sessao,

    # Caminho do repositorio privado (fonte do material)
    [string] $Origem = (Join-Path (Split-Path $PSScriptRoot -Parent) 'Aula_PLN_FATEC'),

    # Faz git add/commit/push ao final
    [switch] $Commit
)

$ErrorActionPreference = 'Stop'

$origemMateriais = Join-Path $Origem 'Materiais'
$destinoMateriais = Join-Path $PSScriptRoot 'Materiais'

if (-not (Test-Path $origemMateriais)) {
    throw "Nao encontrei a pasta de origem: $origemMateriais. Use -Origem para apontar o caminho do repo privado."
}

$extensoes = @('.pdf', '.pptx', '.ipynb')

# Quais sessoes considerar: as ja publicadas + as pedidas via -Sessao
$publicadas = @()
if (Test-Path $destinoMateriais) {
    $publicadas = Get-ChildItem $destinoMateriais -Directory | Select-Object -ExpandProperty Name
}

$alvos = Get-ChildItem $origemMateriais -Directory | Where-Object {
    $nome = $_.Name
    ($publicadas -contains $nome) -or ($Sessao | Where-Object { $nome.StartsWith($_) })
}

if (-not $alvos) {
    Write-Host "Nada a sincronizar. Use -Sessao <prefixo> para publicar uma sessao nova." -ForegroundColor Yellow
    return
}

$copiados = 0
foreach ($pasta in $alvos) {
    $arquivos = Get-ChildItem $pasta.FullName -File | Where-Object { $extensoes -contains $_.Extension.ToLower() }
    if (-not $arquivos) { continue }

    $destinoPasta = Join-Path $destinoMateriais $pasta.Name
    if (-not (Test-Path $destinoPasta)) { New-Item -ItemType Directory -Path $destinoPasta -Force | Out-Null }

    foreach ($arq in $arquivos) {
        $destinoArq = Join-Path $destinoPasta $arq.Name
        $mudou = -not (Test-Path $destinoArq) -or
                 ((Get-Item $destinoArq).Length -ne $arq.Length) -or
                 ((Get-Item $destinoArq).LastWriteTimeUtc -ne $arq.LastWriteTimeUtc)
        if ($mudou) {
            Copy-Item $arq.FullName $destinoArq -Force
            Write-Host "  atualizado: $($pasta.Name)/$($arq.Name)" -ForegroundColor Green
            $copiados++
        }
    }
}

if ($copiados -eq 0) {
    Write-Host "Tudo ja estava atualizado." -ForegroundColor Cyan
} else {
    Write-Host "$copiados arquivo(s) atualizado(s)." -ForegroundColor Cyan
    Write-Host "Lembre-se de conferir a tabela de sessoes no README.md." -ForegroundColor Yellow
}

if ($Commit) {
    Push-Location $PSScriptRoot
    try {
        git add -A
        $pendente = git status --porcelain
        if ($pendente) {
            git commit -m "Atualiza material das aulas"
            git push
        } else {
            Write-Host "Nada para commitar." -ForegroundColor Cyan
        }
    } finally {
        Pop-Location
    }
}
