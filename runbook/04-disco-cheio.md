# Disco cheio (pouco espaço livre)

| | |
|---|---|
| **Categoria** | Sistema |
| **Nível de atendimento** | N1, com escalonamento para N2 em casos de hardware ou de crescimento anormal |
| **Testado** | Parcial. Os comandos de diagnóstico (espaço livre pelo kit, tamanho das pastas do usuário, do `AppData\Local` e do `Temp`) foram executados em um computador real. As limpezas descritas na solução não foram aplicadas |
| **Altera o sistema?** | Diagnóstico: não (somente leitura). Solução: sim, ver passos marcados |

## Sintoma

"O disco está cheio", "o Windows avisa que há pouco espaço", atualizações que falham, programas que não conseguem salvar arquivos. No relatório do kit, aparece na linha **Disco** do Resumo como `ATENCAO` (menos de 20% livre) ou `CRITICO` (menos de 10% livre).

## Como confirmar (diagnóstico)

A técnica é sempre a mesma: **do maior para o menor, um nível por vez**. Em vez de procurar arquivos grandes ao acaso, mede-se cada pasta, descobre-se qual é a maior e repete-se a medição dentro dela.

1. **Rodar o kit** e anotar o espaço livre e o percentual do disco.

   ```powershell
   .\scripts\Get-SystemDiagnostic.ps1
   ```

2. **Medir as pastas do usuário.** O comando pode demorar alguns minutos, e dá para interromper com Ctrl+C:

   ```powershell
   Get-ChildItem $env:USERPROFILE -Directory -Force -ErrorAction SilentlyContinue |
       ForEach-Object {
           $t = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
           [PSCustomObject]@{ Pasta = $_.Name; GB = [math]::Round($t / 1GB, 2) }
       } | Sort-Object GB -Descending | Select-Object -First 8
   ```

3. **Descer um nível na maior pasta.** Se a maior for a `AppData` (onde os programas guardam dados e caches), medir o `AppData\Local`:

   ```powershell
   Get-ChildItem $env:LOCALAPPDATA -Directory -Force -ErrorAction SilentlyContinue |
       ForEach-Object {
           $t = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
           [PSCustomObject]@{ Pasta = $_.Name; GB = [math]::Round($t / 1GB, 2) }
       } | Sort-Object GB -Descending | Select-Object -First 8
   ```

4. **Ver o que há dentro do `Temp`**, onde os programas deixam arquivos temporários:

   ```powershell
   Get-ChildItem $env:TEMP -Force -ErrorAction SilentlyContinue |
       ForEach-Object {
           if ($_.PSIsContainer) { $t = (Get-ChildItem $_.FullName -Recurse -File -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
           else { $t = $_.Length }
           [PSCustomObject]@{ Item = $_.Name; GB = [math]::Round($t / 1GB, 2) }
       } | Sort-Object GB -Descending | Select-Object -First 8
   ```

5. **Ver o que ocupa espaço fora da pasta do usuário** (Windows, Program Files, arquivo de hibernação) usando a tela do próprio Windows: Configurações, Sistema, Armazenamento. Ela mostra o espaço por categoria sem precisar de comandos.

**Limites desta medição.** Os comandos olham apenas a pasta do usuário, e o espaço restante do disco fica de fora. Além disso, arquivos do OneDrive que existem só na nuvem podem aparecer com o tamanho total sem ocupar espaço local.

## Onde o espaço costuma estar

| O maior consumo está em | Causa provável | O que fazer |
|---|---|---|
| Downloads, Vídeos, Imagens, Área de Trabalho | Arquivos do próprio usuário | Orientar a organizar, mover para a nuvem ou para um disco externo. Não apagar sem autorização do usuário |
| `AppData\Local\Temp` | Arquivos temporários que os programas não limparam | Limpeza pelo Windows (passo 1 da solução) |
| `AppData\Local\<programa>` | Cache e dados do programa | Limpar pelo próprio programa ou desinstalar o que não é usado |
| Fora da pasta do usuário | Atualizações do Windows, programas instalados, hibernação | Usar a tela de Armazenamento do Windows e, se necessário, escalar |

## Causas prováveis

1. Arquivos temporários acumulados.
2. Cache de navegadores, jogos e aplicativos.
3. Programas instalados que não são mais usados.
4. Arquivos pessoais grandes (vídeos, downloads antigos).
5. Atualizações e pontos de restauração do Windows.
6. Um programa com defeito gerando arquivos continuamente.

## Solução

Do mais seguro para o menos seguro:

1. **Limpeza pelo Windows**: Configurações, Sistema, Armazenamento, Arquivos temporários. Marcar o que será removido e confirmar. O Windows ignora o que está em uso. **Não marcar a opção "Downloads" sem antes conferir o conteúdo da pasta.**
2. **Ativar o Sensor de armazenamento** (na mesma tela) para limpeza automática.
3. **Limpar o cache pelo próprio programa** (por exemplo, nas configurações do navegador) e **desinstalar o que não é usado** em Configurações, Aplicativos.
4. **Esvaziar a lixeira.**
5. **Opcional e mais arriscado**, só com os programas fechados e depois de reiniciar: listar antes o que seria apagado do `Temp` com mais de 7 dias, e só então apagar.

   ```powershell
   Get-ChildItem $env:TEMP -Force | Where-Object LastWriteTime -lt (Get-Date).AddDays(-7) |
       Remove-Item -Recurse -Force -WhatIf
   ```

   O `-WhatIf` apenas mostra o que seria removido. A remoção de verdade exige tirar o `-WhatIf`, e **só deve ser feita depois de conferir a lista**.
6. **Arquivos pessoais**: orientar o usuário a decidir o que mover ou apagar.

## Quando escalar

- O espaço some de novo rápido depois da limpeza (algo está gerando arquivos continuamente).
- O Windows ou os programas instalados ocupam muito espaço sem explicação.
- O disco apresenta erros ou lentidão extrema.
- É necessário ampliar o armazenamento (trocar ou acrescentar disco).
- O computador tem política de retenção de arquivos da empresa.

## O que registrar no chamado

- O espaço livre antes e depois de qualquer limpeza.
- Onde estava o maior consumo e o que foi removido.
- O que foi orientado ao usuário (arquivos dele não foram apagados sem autorização).

## Exemplo real

O relatório marcou o disco como `ATENCAO`: 28,6 GB livres de 237,5 GB (12%). As pastas pessoais não eram o problema: Downloads tinha 0,41 GB e Vídeos 0,39 GB. A maior pasta do usuário era a `AppData`, com 70,48 GB, mais de dez vezes o OneDrive (5,79 GB, valor que pode incluir arquivos só online).

Dentro de `AppData\Local`, as maiores pastas eram `Temp` (21,37 GB), `Google` (10,22 GB), `Roblox` (6,74 GB), `Microsoft` (5,12 GB), `Programs` (4,82 GB), `SquirrelTemp` (4,54 GB), `CapCut` (2,3 GB) e `GitHubDesktop` (2,15 GB).

Dentro do `Temp`, o maior item era uma pasta de nome aleatório com 4,28 GB, seguida de vários arquivos `wct*.tmp` de cerca de 0,12 a 0,14 GB cada. Relatos de usuários em fóruns associam arquivos `wct*.tmp` a restos de instaladores do OneDrive, mas essa origem **não foi confirmada** neste computador.

Somando só as oito maiores pastas da pasta do usuário, o total chega a cerca de 80 GB, e o disco tinha cerca de 209 GB ocupados. Portanto, algo como 130 GB estão fora da pasta do usuário, e o que ocupa esse espaço não foi medido. Se todos os 21,4 GB do `Temp` pudessem ser removidos, o espaço livre iria de 28,6 GB para cerca de 50 GB (perto de 21%), mas parte desses arquivos provavelmente está em uso. Nenhuma limpeza foi aplicada: o caso documenta apenas o diagnóstico.
