# Programa travando ou "não está respondendo"

| | |
|---|---|
| **Categoria** | Aplicativo |
| **Nível de atendimento** | N1, com escalonamento para N2 em travamentos recorrentes ou em vários programas |
| **Testado** | Parcial. A consulta aos eventos de travamento foi executada em um computador real e retornou um caso verdadeiro. As correções descritas na solução não foram aplicadas |
| **Altera o sistema?** | Diagnóstico: não (somente leitura). Solução: sim, ver passos marcados |

## Sintoma

A janela do programa fica congelada, aparece "(Não está respondendo)" na barra de título, o programa fecha sozinho ou o usuário precisa forçar o encerramento. No relatório do kit, pode aparecer na tabela **Erros recentes** como `Application Hang` (ID 1002) ou `Application Error` (ID 1000).

## Como confirmar (diagnóstico)

1. **Ler os eventos de travamento e de falha dos últimos 7 dias:**

   ```powershell
   Get-WinEvent -FilterHashtable @{LogName='Application'; Id=1000,1002; StartTime=(Get-Date).AddDays(-7)} -ErrorAction SilentlyContinue |
       Select-Object TimeCreated, Id, ProviderName, Message | Format-List
   ```

2. **Ler a coluna `ProviderName` junto com o `Id`.** O mesmo número de evento é usado por provedores diferentes:

   | Provedor | Id | Significado |
   |---|---|---|
   | `Application Hang` | 1002 | O programa parou de responder e foi fechado |
   | `Application Error` | 1000 | O programa falhou (a mensagem indica o módulo que falhou) |
   | Outros (por exemplo, `.NET Runtime`) | 1000 | Registro de outro tipo, que não é uma falha de programa |

3. **Anotar o programa e a versão** que aparecem na mensagem do evento.

4. **Ver o estado do computador** no mesmo período: memória, disco e dias sem reiniciar, no relatório do kit (veja as entradas 03 e 04).

   ```powershell
   .\scripts\Get-SystemDiagnostic.ps1
   ```

5. **Procurar um padrão.** É sempre o mesmo programa? Acontece no mesmo horário? Começou depois de uma atualização? Para ver o histórico de falhas por data, abrir o Monitor de Confiabilidade com `perfmon /rel`.

**Como interpretar:**

| Padrão | Interpretação |
|---|---|
| Um travamento isolado em vários dias | Provável sobrecarga momentânea. Registrar e observar |
| O mesmo programa travando repetidamente | Problema do programa: atualizar, reparar ou reinstalar |
| Vários programas diferentes travando | Problema de recurso do sistema (memória, disco, hardware): ver entradas 03 e 04 |
| `Application Error` repetindo o mesmo módulo com falha | Problema numa biblioteca ou driver específico: escalar |

## Causas prováveis

1. Pouca memória ou pouco espaço em disco no momento.
2. Versão do programa com defeito ou desatualizada.
3. Cache ou dados do programa corrompidos.
4. Extensões ou plugins com problema.
5. Conflito com antivírus.
6. Driver de vídeo, em programas que usam aceleração gráfica.

## Solução

1. **Esperar de 30 a 60 segundos** antes de forçar o fechamento: o programa pode estar processando algo pesado.
2. Se continuar congelado, abrir o Gerenciador de Tarefas (**Ctrl+Shift+Esc**) e usar **Finalizar tarefa** no programa. Avisar o usuário de que o trabalho não salvo pode ser perdido.
3. Reabrir o programa e ver se o problema se repete.
4. Liberar recursos: fechar outros programas (entrada 03) e liberar espaço em disco (entrada 04).
5. **Atualizar** o programa para a versão mais recente.
6. Se o programa tem opção de limpar o cache, usá-la. Para aplicativos da loja do Windows, Configurações, Aplicativos, Opções avançadas, Reparar e, se não resolver, Redefinir. Para programas comuns, reinstalar.
7. Se o programa tiver opção de aceleração de hardware, testar com ela desativada.
8. Reiniciar o computador.

## Quando escalar

- Vários programas diferentes travando.
- Travamentos todos os dias ou várias vezes por dia.
- `Application Error` repetido com o mesmo módulo com falha.
- Perda de dados do usuário.
- Suspeita de memória ou disco com defeito.
- Programa corporativo: acionar o fornecedor ou a equipe responsável pela aplicação.

## O que registrar no chamado

- Nome e versão do programa.
- Horário e frequência dos travamentos.
- O ID, o provedor e a mensagem do evento.
- Memória e espaço em disco no momento, se disponíveis.
- As ações feitas e se o problema voltou.

## Exemplo real

Em 05/11/2026, às 20:02:51, o log registrou um evento `Application Hang` (ID 1002): o Slack, versão 4.51.180.0, parou de responder ao Windows e foi fechado. Na consulta dos últimos 7 dias, esse foi o **único** travamento real, ou seja, um caso isolado.

A mesma consulta retornou também um evento de ID 1000 em 12/11/2026, às 09:38:10, mas com o provedor `.NET Runtime`. A mensagem tratava de uma falha numa solicitação ao serviço de elevação (código `0x80004002`) e não descrevia uma falha de programa. Esse registro não foi investigado. Ele mostra por que o provedor precisa ser lido junto com o ID.

Nos dias próximos ao travamento, o computador estava com pouca memória livre (as medições ficaram entre cerca de 1,3 e 2,9 GB livres de 9,9 GB), mas a memória não foi medida no instante exato do travamento, então a relação entre os dois é uma hipótese. Nenhuma ação foi aplicada: o caso documenta apenas o diagnóstico.
