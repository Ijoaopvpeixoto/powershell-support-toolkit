# Computador lento

| | |
|---|---|
| **Categoria** | Sistema |
| **Nível de atendimento** | N1, com escalonamento para N2 se houver suspeita de hardware ou malware |
| **Testado** | Parcial. Todos os comandos de diagnóstico (memória por programa, memória disponível, uso atual de CPU e programas na inicialização) foram executados em um computador real. As correções (desativar programas na inicialização, reiniciar) não foram aplicadas |
| **Altera o sistema?** | Diagnóstico: não (somente leitura). Solução: sim, ver passos marcados |

## Sintoma

"O computador está lento", "trava", "demora para abrir os programas". No relatório do kit, os indícios aparecem no Resumo: **Memória** ou **Disco** em `ATENCAO` ou `CRITICO`, ou **Uptime** em `ATENCAO` (mais de 14 dias sem reiniciar).

## Como confirmar (diagnóstico)

Lentidão quase nunca tem uma causa só. A ordem abaixo vai das causas mais comuns e baratas de checar para as mais raras.

1. **Rodar o kit** e ler o Resumo: memória livre, disco livre e dias sem reiniciar.

   ```powershell
   .\scripts\Get-SystemDiagnostic.ps1
   ```

2. **Memória por programa.** Um navegador abre vários processos com o mesmo nome, por isso o comando agrupa pelo nome e soma:

   ```powershell
   Get-Process | Group-Object Name |
       Select-Object Name, Count, @{Name='MemoriaMB'; Expression={[math]::Round(($_.Group | Measure-Object WorkingSet64 -Sum).Sum / 1MB)}} |
       Sort-Object MemoriaMB -Descending | Select-Object -First 8
   ```

   A soma pode **superestimar** o total, porque páginas de memória compartilhadas entre processos são contadas em cada um. Serve para comparar programas entre si, e não como valor exato.

3. **Memória disponível**, para confirmar o valor do relatório:

   ```powershell
   (Get-CimInstance Win32_PerfFormattedData_PerfOS_Memory).AvailableMBytes / 1024
   ```

   O resultado é em GB. Num caso testado, esse valor ficou praticamente igual ao `RamLivreGB` do relatório.

4. **Uso de CPU neste momento.** A coluna `CPU` do `Get-Process` é o tempo **acumulado** desde que o processo iniciou, e não o uso atual. Para o uso atual:

   ```powershell
   Get-CimInstance Win32_PerfFormattedData_PerfOS_Processor -Filter "Name='_Total'" |
       Select-Object PercentProcessorTime

   Get-CimInstance Win32_PerfFormattedData_PerfProc_Process |
       Where-Object { $_.Name -notin '_Total','Idle' } |
       Sort-Object PercentProcessorTime -Descending |
       Select-Object -First 5 Name, PercentProcessorTime
   ```

   Na segunda lista, o valor de cada processo é relativo a **um núcleo**, enquanto o total é calculado sobre todos os núcleos. Por isso a soma dos processos pode ser maior que o total. É uma amostra de um instante, então vale repetir o comando algumas vezes. Programas com várias instâncias aparecem com sufixo, como `chrome#11`.

5. **Programas que iniciam com o Windows:**

   ```powershell
   Get-CimInstance Win32_StartupCommand | Select-Object Name
   ```

   O comando lista a pasta de inicialização e as chaves `Run` do registro. Tarefas agendadas e serviços não aparecem.

6. **Sinais de pressão de memória**: o processo `Memory Compression` com tamanho grande (centenas de MB) indica que o Windows está comprimindo memória por falta de RAM.

## Causas prováveis

1. Muitos programas e abas abertos ao mesmo tempo para a memória disponível.
2. Muitos programas iniciando junto com o Windows.
3. Muitos dias sem reiniciar de verdade. Com a inicialização rápida ligada, **Desligar** não equivale a **Reiniciar**.
4. Pouco espaço livre no disco.
5. Verificação do antivírus em andamento (o processo `MsMpEng`).
6. Hardware insuficiente, disco com defeito ou malware, quando nada acima explica.

## Solução

1. Fechar programas e abas que não estão em uso. No Chrome, **Shift+Esc** abre o gerenciador de tarefas do navegador, que mostra qual aba consome mais.
2. Se o `Uptime` do relatório estiver acima de 14 dias, **reiniciar** o computador (a opção Reiniciar, e não Desligar).
3. **Reduzir a inicialização**: abrir o Gerenciador de Tarefas (**Ctrl+Shift+Esc**), aba de aplicativos de inicialização, e desativar o que não é necessário. A ação é reversível. **Não desativar** itens de segurança nem de drivers (por exemplo, `SecurityHealth` e o serviço de áudio).
4. Se o disco estiver com pouco espaço livre, seguir a entrada 04 (disco cheio).
5. Se o `MsMpEng` estiver com uso alto de CPU, esperar a verificação terminar antes de qualquer outra ação.

## Quando escalar

- A lentidão continua depois de reiniciar e de reduzir a inicialização.
- O disco apresenta erros ou barulhos incomuns (suspeita de defeito).
- A memória fica sempre no limite mesmo com poucos programas abertos: avaliar aumento de RAM.
- Suspeita de malware: processos desconhecidos com uso alto e constante de CPU ou rede.
- A lentidão afeta vários usuários ao mesmo tempo: pode ser rede ou servidor, e não a máquina.

## O que registrar no chamado

- Desde quando a lentidão ocorre e se é constante ou em horários específicos.
- Os programas abertos no momento.
- Memória disponível, espaço livre em disco e dias sem reiniciar.
- Os programas que mais consomem memória e CPU.
- As ações feitas e se houve melhora.

## Exemplo real

Em um computador com 9,9 GB de RAM utilizável, o diagnóstico mostrou cerca de 2,1 GB de memória disponível (aproximadamente 21%). O navegador, com 32 processos, somava cerca de 4,7 GB (valor possivelmente inflado por memória compartilhada), seguido do Slack (7 processos, cerca de 0,5 GB). O uso total de CPU naquele instante era de 4%, então o processador não era o gargalo. O processo `Memory Compression` aparecia com 366 MB, um indício de pressão de memória. A inicialização continha 13 programas, a maioria dispensável (lançadores de jogos, mensageiros e navegadores). Um evento `Application Hang` do Slack, dias antes, foi registrado em um período de pouca memória livre, o que pode estar relacionado (hipótese, não confirmada). Nenhuma alteração foi aplicada: o caso documenta apenas o diagnóstico.
