# Sem acesso à internet

| | |
|---|---|
| **Categoria** | Rede |
| **Nível de atendimento** | N1 |
| **Testado** | Parcial. O diagnóstico foi executado em ambiente saudável e com uma falha simulada de DNS público. As soluções por camada não foram reproduzidas em uma falha real |
| **Altera o sistema?** | Diagnóstico: não (somente leitura). Solução: sim, ver passos marcados |

## Sintoma

"A internet não funciona", "as páginas não abrem", "está sem internet". No relatório do kit, aparece como `False` em algum item da tabela **Testes de conectividade** e como `CRITICO` em **Conectividade** no Resumo.

## Como confirmar (diagnóstico)

O primeiro passo é rodar o kit e ler a tabela de conectividade **de cima para baixo**. Os testes seguem a ordem das camadas, então o primeiro que falha indica onde está o problema.

```powershell
.\scripts\Get-SystemDiagnostic.ps1
```

Os mesmos testes, feitos manualmente:

```powershell
Get-NetIPConfiguration
Test-NetConnection <endereço do gateway>
Test-NetConnection 8.8.8.8
Resolve-DnsName google.com
Resolve-DnsName google.com -Server 8.8.8.8
Test-NetConnection google.com -Port 443
```

| Resultado | Camada | Causa provável |
|---|---|---|
| Gateway falha | Local | Wi-Fi ou cabo desconectado, adaptador desativado, modo avião, roteador desligado. Se o IP começa com `169.254`, o DHCP não respondeu |
| Gateway ok, `8.8.8.8` falha | Roteador até o provedor | Link do provedor caído ou roteador sem sincronismo |
| `8.8.8.8` ok, DNS do sistema falha, DNS público ok | DNS configurado | O servidor DNS do roteador ou do provedor está com problema |
| `8.8.8.8` ok e os dois DNS falham | Consulta DNS | Firewall ou rede restrita bloqueando consultas DNS |
| Tudo ok, só a porta 443 falha | Aplicação ou segurança | Proxy, firewall, antivírus, ou problema no site específico |

Cuidado ao interpretar: algumas redes bloqueiam o ping (ICMP) de propósito, e um ping falhando no gateway não prova que ele está fora do ar. Por isso o último teste usa uma conexão TCP real na porta 443.

## Causas prováveis

1. Conexão Wi-Fi ou cabo caída, ou adaptador desativado.
2. Roteador ou modem travado.
3. Falha no provedor.
4. Servidor DNS com problema.
5. Proxy, firewall ou antivírus bloqueando o tráfego.

## Solução

**Gateway falha**

1. Conferir se o Wi-Fi está conectado, se o modo avião está desligado e, havendo cabo, se ele está firme.
2. Ver o estado do adaptador com `Get-NetAdapter`. Se o status não for `Up`:
   - **(Administrador)** `Enable-NetAdapter -Name "Wi-Fi"`, ou
   - **(Administrador)** `Restart-NetAdapter -Name "Wi-Fi"` (a conexão cai por alguns segundos).
3. Se o IP começa com `169.254`, renovar o endereço (a conexão cai por alguns segundos):
   ```powershell
   ipconfig /release
   ipconfig /renew
   ```
4. Reiniciar o roteador, esperar cerca de 2 minutos e testar outro dispositivo na mesma rede.

**Gateway ok, internet por IP falha**

1. Testar outro dispositivo na mesma rede.
2. Reiniciar roteador e modem.
3. Se vários dispositivos estão sem internet, o problema é do provedor: abrir chamado com ele.

**DNS falha**

1. Limpar o cache de DNS:
   ```powershell
   ipconfig /flushdns
   ```
2. Se `Resolve-DnsName google.com -Server 8.8.8.8` funciona mas o DNS do sistema não, o servidor configurado é o problema. Anotar o DNS atual (aparece em `Get-NetIPConfiguration`) e trocar temporariamente:
   - **(Administrador)** `Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ServerAddresses 1.1.1.1,8.8.8.8`
3. Para desfazer e voltar ao automático:
   - **(Administrador)** `Set-DnsClientServerAddress -InterfaceAlias "Wi-Fi" -ResetServerAddresses`

Em ambiente corporativo, **não trocar o DNS por conta própria**: a rede pode depender de um DNS interno, e a troca pode violar a política da empresa. Nesse caso, escalar.

**Só a porta 443 falha**

1. Ver se há proxy configurado: `netsh winhttp show proxy`, e em Configurações, Rede e Internet, Proxy.
2. Testar em outro navegador.
3. Verificar se firewall ou antivírus está bloqueando o acesso.

## Quando escalar

- Vários dispositivos sem internet e o gateway respondendo: provedor ou infraestrutura de rede.
- O adaptador de rede não aparece em `Get-NetAdapter`: driver ou hardware (N2).
- Falha de DNS em ambiente corporativo com DNS interno: infraestrutura de rede.
- Nenhum passo acima resolveu: N2, com o relatório anexado.

## O que registrar no chamado

- Qual teste do relatório falhou primeiro e o horário.
- Se o problema afeta só uma máquina ou várias.
- O DNS original, caso tenha sido alterado.
- As ações feitas e o resultado de cada uma.

## Exemplo real

No ambiente de teste, os cinco testes passaram (linha de base saudável). O cenário de falha foi simulado apontando o teste de DNS público para `192.0.2.1`, um bloco reservado para documentação em que nenhum servidor responde. O relatório marcou a linha `DNS publico` como `False` e o Resumo exibiu `CRITICO | Conectividade | Falhou: DNS publico`. Depois o endereço foi restaurado para `8.8.8.8` e o relatório voltou a ficar verde.
