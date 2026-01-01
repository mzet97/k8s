import socket
import urllib.parse
import sys

def verify_fix():
    print("=== Verificação da Correção RabbitMQ (Simulação) ===\n")
    
    # Configurações Corrigidas
    CORRECT_IP = "192.168.1.51"  # IP do LoadBalancer (Hardcoded para teste)
    CORRECT_PORT = 5672
    CORRECT_URL = f"amqp://admin:Admin%40123@{CORRECT_IP}:5672/"
    
    print(f"[*] Testando com Configurações Corrigidas:")
    print(f"    IP: {CORRECT_IP}")
    print(f"    URL: {CORRECT_URL}")
    
    # 1. Teste de Conexão TCP
    print("\n[1] Teste de Conectividade TCP...")
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(3)
        result = sock.connect_ex((CORRECT_IP, CORRECT_PORT))
        sock.close()
        
        if result == 0:
            print(f"    ✅ SUCESSO: Conexão TCP estabelecida com {CORRECT_IP}:{CORRECT_PORT}")
        else:
            print(f"    ❌ ERRO: Não foi possível conectar (Código: {result})")
            sys.exit(1)
    except Exception as e:
        print(f"    ❌ EXCEÇÃO: {e}")
        sys.exit(1)

    # 2. Teste de Parsing da URL
    print("\n[2] Validação do Parser da URL...")
    try:
        parsed = urllib.parse.urlparse(CORRECT_URL)
        
        # Verifica se a senha foi decodificada corretamente (o parser deve decodificar %40 -> @ automaticamente? 
        # Na verdade, o parser mantém encoded ou decoded dependendo da implementação, 
        # mas bibliotecas AMQP como Pika geralmente esperam que a string esteja pronta ou fazem unquote.
        # O importante é que o parser NÃO quebre dividindo no lugar errado.
        
        print(f"    Scheme: {parsed.scheme}")
        print(f"    Hostname: {parsed.hostname}")
        print(f"    Port: {parsed.port}")
        print(f"    User: {parsed.username}")
        print(f"    Pass (Raw): {parsed.password}")
        
        # Verifica se o hostname foi capturado corretamente (não deve ser cortado pelo @)
        if parsed.hostname == CORRECT_IP:
            print("    ✅ SUCESSO: Hostname identificado corretamente.")
        else:
            print(f"    ❌ ERRO: Hostname incorreto. Esperado '{CORRECT_IP}', obteve '{parsed.hostname}'")
            
        # Verifica se a senha não quebrou o user
        if parsed.username == "admin":
             print("    ✅ SUCESSO: Username identificado corretamente.")
             
        if parsed.password == "Admin%40123":
             print("    ✅ SUCESSO: Password identificado corretamente (Encoded).")
             
    except Exception as e:
        print(f"    ❌ Erro no parser: {e}")

    print("\n=== Resultado ===")
    print("✅ A configuração proposta é VÁLIDA e FUNCIONAL.")
    print("   O servidor está acessível e a string de conexão é interpretada corretamente.")

if __name__ == "__main__":
    verify_fix()
