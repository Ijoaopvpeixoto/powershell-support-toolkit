# Runbook de suporte

Procedimentos para problemas comuns de suporte (nível N1) em computadores Windows. Cada entrada segue o mesmo formato: **sintoma, como confirmar (diagnóstico), causas prováveis, solução, quando escalar, o que registrar no chamado e um exemplo real.**

O runbook trabalha junto com o script do projeto: o relatório gerado por `scripts\Get-SystemDiagnostic.ps1` indica onde olhar, e cada entrada explica o que fazer a partir dali.

## Convenções

- **Diagnóstico é somente leitura.** Os comandos de diagnóstico não alteram nada no computador.
- **(Administrador)** marca os passos de solução que alteram o sistema e exigem o PowerShell aberto como Administrador.
- **Testado** informa, em cada entrada, o que foi de fato executado. Nenhuma entrada declara como testado algo que não foi executado. Hoje todas estão como **Parcial**: os comandos de diagnóstico foram executados em um computador real, mas as correções não foram aplicadas.
- Em ambiente corporativo, as políticas da empresa prevalecem sobre qualquer passo daqui. Na dúvida, escalar.

## Entradas escritas

| # | Problema | Categoria | Testado | Base do exemplo real |
|---|---|---|---|---|
| 01 | [Sem acesso à internet](01-sem-internet.md) | Rede | Parcial | Falha simulada de DNS público |
| 02 | [Serviço não iniciou no boot](02-servico-nao-iniciou-no-boot.md) | Sistema | Parcial | Eventos 7000 e 7009 do serviço de atualização do Google |
| 03 | [Computador lento](03-computador-lento.md) | Sistema | Parcial | Memória, CPU e programas na inicialização |
| 04 | [Disco cheio](04-disco-cheio.md) | Sistema | Parcial | Disco com 12% livre e espaço concentrado em `AppData` |
| 05 | [Programa travando](05-programa-travando.md) | Aplicativo | Parcial | Evento `Application Hang` de um programa de mensagens |

## Entradas planejadas

Ainda **não foram escritas nem testadas**.

| # | Problema |
|---|---|
| 06 | Impressora não imprime (fila travada, serviço Spooler) |
| 07 | Arquivos de sistema corrompidos (`sfc` e `DISM`) |
| 08 | Windows Update falhando |
| 09 | Reinício inesperado ou tela azul (evento Kernel-Power 41) |

## Escrever uma nova entrada

Use o [modelo](00-template.md). Preencha o campo **Testado** com honestidade: diga o que foi executado e o que não foi.
