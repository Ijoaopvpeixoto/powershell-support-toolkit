# PowerShell Support Toolkit

Kit de diagnóstico e runbook de suporte para Windows, feito em PowerShell 5.1.

## Visão geral

Um script coleta informações do computador, testa a conectividade em camadas e gera um **relatório HTML** com os achados classificados em `OK`, `ATENCAO` e `CRITICO`. Ao lado do script, um **runbook** documenta problemas comuns de suporte no formato *sintoma, diagnóstico, solução e quando escalar*.

É um projeto de estudo e portfólio, feito para treinar o raciocínio de diagnóstico de suporte e infraestrutura.

O script **não altera configurações do computador**. Ele só lê informações e grava o relatório na pasta `reports\` do próprio projeto.

<!--
Quando tiver um print do relatório SEM dados pessoais, salve em screenshots/relatorio-exemplo.png
e remova as marcas de comentário da linha abaixo:
![Relatório de exemplo](screenshots/relatorio-exemplo.png)
-->

## O que o kit verifica

| Área | O que é verificado |
|---|---|
| Sistema | Nome do computador, versão do Windows, dias desde o último boot, processador, núcleos, memória total e livre |
| Disco | Tamanho, espaço livre e percentual livre dos discos locais |
| Rede | Interface ativa, IPv4, gateway e servidores DNS |
| Conectividade | Cinco testes em camadas (ver abaixo) |
| Serviços críticos | `Dnscache`, `Dhcp`, `WlanSvc`, `EventLog`, `Winmgmt`, `mpssvc`, `WinDefend`, `Spooler`, `LanmanWorkstation` |
| Eventos | Erros e eventos críticos dos logs System e Application nas últimas 24 horas (até 15, os mais recentes) |

### Conectividade em camadas

Os testes seguem a ordem em que um técnico diagnosticaria, da camada mais próxima para a mais distante. O primeiro que falha indica onde está o problema.

1. Ping no gateway
2. Ping em `8.8.8.8` (internet por IP, sem depender de DNS)
3. Resolução de nome pelo DNS do sistema
4. Resolução de nome por um DNS público (`8.8.8.8`)
5. Conexão TCP na porta 443

O último teste usa uma conexão TCP real porque algumas redes bloqueiam ping de propósito.

## Limites de alerta

Os limites são decisões de projeto, e não padrões oficiais.

| Item | `ATENCAO` | `CRITICO` |
|---|---|---|
| Disco livre | menos de 20% | menos de 10% |
| Memória livre | menos de 20% | menos de 10% |
| Dias sem reiniciar | mais de 14 | n/a |
| Conectividade | n/a | qualquer teste falhou |
| Serviços | início automático e fora de execução | n/a |
| Eventos | 10 erros ou mais em 24 h | n/a |

## Como executar

Requisitos: Windows 10 ou 11 com Windows PowerShell 5.1 (já instalado). Não precisa de Administrador.

```powershell
git clone <URL deste repositório>
cd powershell-support-toolkit
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser
.\scripts\Get-SystemDiagnostic.ps1
```

- O `Set-ExecutionPolicy` com `-Scope CurrentUser` vale só para o seu usuário. O `RemoteSigned` permite scripts locais e exige assinatura para os baixados da internet.
- Se baixar o ZIP do repositório em vez de clonar, o Windows pode marcar os arquivos como baixados da internet e bloqueá-los. Nesse caso, rode `Unblock-File .\scripts\Get-SystemDiagnostic.ps1`.
- O relatório é salvo em `reports\diagnostico-<COMPUTADOR>-<data>-<hora>.html` e abre no navegador padrão.

## Estrutura do repositório

```
powershell-support-toolkit/
├── README.md
├── scripts/
│   └── Get-SystemDiagnostic.ps1
├── runbook/
│   ├── README.md
│   ├── 00-template.md
│   ├── 01-sem-internet.md
│   ├── 02-servico-nao-iniciou-no-boot.md
│   ├── 03-computador-lento.md
│   ├── 04-disco-cheio.md
│   └── 05-programa-travando.md
├── samples/
│   └── exemplo-relatorio.html
└── .gitignore            (ignora a pasta reports/)
```

## Runbook

O [runbook](runbook/README.md) tem 5 entradas escritas e 4 planejadas. Cada entrada traz o sintoma, os comandos de diagnóstico, as causas prováveis, a solução, os critérios para escalar e um exemplo real. Os exemplos vêm de um computador de teste, e cada entrada informa o que foi e o que não foi testado.

## Decisões de projeto

- **PowerShell 5.1 como alvo.** Ele já vem instalado no Windows 10 e 11, então o script roda em qualquer computador sem instalar nada.
- **Funções devolvem objetos, e não texto.** A coleta fica separada da apresentação, e os mesmos dados alimentam o console e o HTML. Os comandos `Format-*` ficam só no fim do pipeline.
- **Somente leitura.** Nenhuma configuração do computador é alterada.
- **Código sem acentos e HTML com entidades.** O código-fonte evita acentos, e o HTML usa entidades (`&oacute;`) e é gravado em UTF-8. Isso evita problemas de codificação do PowerShell 5.1 ao ler arquivos sem BOM.
- **Relatórios fora do Git.** Eles contêm o nome do computador e endereços de rede, então a pasta `reports\` está no `.gitignore`.
- **Alertas por limites simples e explícitos**, fáceis de entender e de ajustar.

## Validação

**Testado:**

- Cenário saudável: os cinco testes de conectividade passaram e os serviços estavam em execução.
- Falha simulada: o teste de DNS público foi apontado para `192.0.2.1` (bloco reservado para documentação, onde nenhum servidor responde). O relatório marcou `CRITICO` em Conectividade, e o endereço foi restaurado depois.
- Os comandos de diagnóstico de cada entrada do runbook foram executados em um computador real. As correções não foram aplicadas, por isso as entradas estão marcadas como "Testado: Parcial".

**Não testado:**

- Outros cenários de falha (disco crítico, serviço parado, ausência de gateway).
- Outros computadores e versões do Windows. Todos os testes foram em um único computador com Windows 11 Home e PowerShell 5.1.
- PowerShell 7.

## Desafios e aprendizados

**1. O script que não fazia nada.** O script rodou sem imprimir nada e sem erro. O motivo: o Bloco de Notas abre e devolve o prompt imediatamente, e o script foi executado enquanto o arquivo ainda estava vazio (e, em outra ocasião, ainda na versão antiga). A saída foi conferir o arquivo antes de executar, com `(Get-Item .\scripts\Get-SystemDiagnostic.ps1).Length` e `Select-String`, e fechar o editor antes de rodar.

**2. Uma hipótese que não se confirmou.** Surgiu a dúvida se o `FreePhysicalMemory` subestimaria a memória realmente disponível, por não contar o cache que o Windows libera quando precisa. Comparei com o contador `Win32_PerfFormattedData_PerfOS_Memory`: 2,10 GB contra 2,03 GB, praticamente iguais. Mantive a medição e descartei a limitação.

**3. O mesmo ID, eventos diferentes.** Ao consultar os eventos 1000 e 1002 do log de aplicativos, o ID 1000 apareceu com o provedor `.NET Runtime`, que não é uma falha de programa (esse papel é do provedor `Application Error`). Conclusão: o ID de um evento nunca deve ser lido sozinho, sempre junto com o `ProviderName`.

**4. Um erro de boot que não era problema.** Os eventos 7000 e 7009 do `Service Control Manager` apontavam o serviço de atualização do Google. Comparando o horário dos eventos (07:44:15) com o do último boot (07:42:00), vi que ocorreram 2 minutos e 15 segundos depois, e o serviço estava em execução depois disso. Classifiquei como atraso de inicialização, sem ação necessária.

### Detalhes técnicos que vale registrar

- `@($null).Count` vale **1** em PowerShell, e não 0. Por isso a contagem de erros filtra os valores nulos antes.
- O `Get-WinEvent` gera um erro quando não encontra nenhum evento, em vez de devolver uma lista vazia. Por isso o `-ErrorAction SilentlyContinue`.
- A coluna `CPU` do `Get-Process` é o tempo **acumulado**, e não o uso atual. Para o uso atual, a classe `Win32_PerfFormattedData_PerfProc_Process` funciona em qualquer idioma do Windows.

## Privacidade

O relatório gerado contém o nome do computador, o endereço IP local e os servidores DNS. Por isso a pasta `reports\` fica fora do Git. O arquivo em `samples\` é uma cópia com o nome do computador e os endereços substituídos por valores genéricos.

## Limitações conhecidas

- O ping pode ser bloqueado em algumas redes, e um ping falhando não prova que o destino está fora do ar.
- O script considera apenas a primeira interface ativa que tenha gateway.
- A lista de serviços críticos e a janela de 24 horas dos eventos são fixas no código.
- As mensagens de eventos são truncadas na tabela do relatório.
- Os limites de alerta são arbitrários e foram escolhidos para este projeto.

## Próximos passos

- Escrever as entradas planejadas do runbook (06 a 09).
- Acrescentar ao relatório o tamanho da pasta `Temp` e os programas que mais consomem memória.
- Aceitar parâmetros de linha de comando (janela de eventos, limites, pasta de saída).
- Exportar os dados também em JSON.
- Escrever testes automatizados com Pester.
- Testar em PowerShell 7 e em outras versões do Windows.
