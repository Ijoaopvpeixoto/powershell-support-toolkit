# Serviço não iniciou no boot (eventos 7000 e 7009)

| | |
|---|---|
| **Categoria** | Sistema |
| **Nível de atendimento** | N1, com escalonamento para N2 em serviços essenciais |
| **Testado** | Parcial. O diagnóstico foi aplicado a um caso real. Os comandos de correção não foram reproduzidos |
| **Altera o sistema?** | Diagnóstico: não (somente leitura). Solução: sim, ver passos marcados |

## Sintoma

Após ligar o computador, aparece um aviso de que um serviço falhou ao iniciar, ou um programa não funciona (por exemplo, um atualizador). No relatório do kit, aparece na tabela **Erros recentes** com os IDs 7000 e 7009 da origem `Service Control Manager`, ou na tabela **Serviços críticos** como um serviço `Automatic` com status diferente de `Running`.

## Como confirmar (diagnóstico)

1. Ler os eventos completos (a tabela do relatório corta a mensagem):

   ```powershell
   Get-WinEvent -FilterHashtable @{LogName='System'; Id=7000,7009; StartTime=(Get-Date).AddHours(-24)} |
       Format-List TimeCreated, Message
   ```

2. Comparar o horário dos eventos com o do último boot:

   ```powershell
   (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
   ```

   Se o evento ocorreu poucos minutos depois do boot, é um problema de inicialização, e não algo que acontece com o computador já em uso.

3. Ver o estado atual do serviço e como ele inicia (trocar `<nome>` pelo nome do serviço que aparece na mensagem):

   ```powershell
   Get-Service <nome> | Select-Object Name, Status, StartType
   sc.exe qc <nome>
   ```

   Escrever `sc.exe` com a extensão: no PowerShell, `sc` é um apelido de `Set-Content`. Na saída, procurar o tipo de início (`AUTO_START (DELAYED)` indica início atrasado) e a linha `DEPENDENCIES`.

**Como ler os eventos.** O 7009 indica que o Windows esperou 30 segundos pela conexão do serviço e desistiu. O 7000 indica que o serviço não conseguiu iniciar. Os dois costumam aparecer juntos e, em geral, são o mesmo incidente registrado duas vezes.

## Causas prováveis

1. Boot sob carga (pouca memória livre ou disco lento), fazendo um serviço de início atrasado estourar o tempo limite.
2. Uma dependência do serviço que ainda não estava pronta.
3. Programa corrompido ou desatualizado.
4. Antivírus ou outro software interferindo no início do serviço.

## Solução

1. Se o serviço está `Running` agora e o evento foi isolado, **não fazer nada**. Registrar e observar nos próximos boots.
2. Se o serviço está parado:
   - **(Administrador)** `Start-Service -Name <nome>`
   - Confirmar com `Get-Service <nome>`.
3. Se o erro se repete em todo boot:
   - Conferir a memória e o disco livres no relatório e os programas que iniciam com o Windows.
   - Atualizar, reparar ou reinstalar o programa dono do serviço.
4. Não alterar o tipo de início de serviços do sistema sem necessidade.

## Quando escalar

- Falha em um serviço essencial do sistema, como `EventLog`, `Dhcp`, `Dnscache` ou `Winmgmt`.
- O mesmo erro em várias máquinas.
- `Start-Service` retorna erro de dependência ou acesso negado de forma persistente.

## O que registrar no chamado

- IDs dos eventos e o horário de cada um.
- O horário do último boot.
- Nome do serviço, estado atual e tipo de início.
- A ação tomada e o resultado.

## Exemplo real

Em 03/11/2026, o relatório listou dois eventos do `Service Control Manager` às 07:44:15, sobre o serviço do Google Update (`gupdate`): o 7009 (tempo limite de 30 segundos) e o 7000 (falha ao iniciar). O boot tinha sido às 07:42:00, ou seja, os eventos ocorreram 2 minutos e 15 segundos depois. Os dois eventos tinham o mesmo horário, o que indica um único incidente. Os demais serviços críticos estavam em execução, e o computador tinha pouca memória livre naquele período, o que pode ter contribuído (hipótese, não confirmada). O caso foi classificado como atraso de inicialização sem impacto, e nenhuma ação foi necessária.
