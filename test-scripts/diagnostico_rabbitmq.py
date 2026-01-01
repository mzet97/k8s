import socket
import sys
import urllib.parse
import time

def check_dns(hostname):
    print(f"[*] Resolvendo DNS para: {hostname}")
    try:
        ip = socket.gethostbyname(hostname)
        print(f"    ✅ Resolvido: {ip}")
        return ip
    except socket.gaierror:
        print(f"    ❌ ERRO: Não foi possível resolver o hostname '{hostname}'")
        return None

def check_tcp_connection(ip, port, timeout=3):
    print(f"[*] Testando conexão TCP em {ip}:{port}...")
    try:
        sock = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
        sock.settimeout(timeout)
        result = sock.connect_ex((ip, port))
        sock.close()
        
        if result == 0:
            print(f"    ✅ Conexão TCP SUCESSO na porta {port}")
            return True
        else:
            print(f"    ❌ ERRO: Porta {port} fechada ou inalessível (Código: {result})")
            return False
    except Exception as e:
        print(f"    ❌ EXCEÇÃO: {e}")
        return False

def check_url_encoding(connection_string):
    print(f"[*] Analisando Connection String...")
    try:
        # Mascarando senha para print
        masked_url = connection_string
        if ":" in connection_string and "@" in connection_string:
            parts = connection_string.split("@")
            if len(parts) > 2: # Tem @ na senha
                print("    ⚠️  ALERTA CRÍTICO: Detectado caractere '@' extra na URL.")
                print("       Isso geralmente quebra o parser da connection string.")
                print("       Sua senha 'Admin@123' deve ser codificada como 'Admin%40123'.")
                return False
        
        parsed = urllib.parse.urlparse(connection_string)
        print(f"    Host identificado: {parsed.hostname}")
        print(f"    Porta identificada: {parsed.port}")
        print(f"    User identificado: {parsed.username}")
        
        if parsed.password and "@" in parsed.password:
             print("    ⚠️  ALERTA: A senha capturada ainda contém '@'. O parser pode ter funcionado por sorte, mas é arriscado.")
        
        return True
    except Exception as e:
        print(f"    ❌ Erro ao parsear URL: {e}")
        return False

def main():
    print("=== Diagnóstico de Conexão RabbitMQ ===\n")
    
    # Dados fornecidos
    conn_str = "amqp://admin:Admin@123@rabbitmq.home.arpa:5672/"
    hostname = "rabbitmq.home.arpa"
    port = 5672
    
    # 1. Análise da String
    print("1. Verificação de Sintaxe da URL")
    url_ok = check_url_encoding(conn_str)
    
    print("\n2. Verificação de Rede")
    resolved_ip = check_dns(hostname)
    
    if resolved_ip:
        # Se resolveu, testa TCP
        tcp_ok = check_tcp_connection(resolved_ip, port)
        
        # Se resolveu para um IP suspeito (como o .31.51 que vimos antes)
        if resolved_ip.startswith("192.168.31."):
             print("\n⚠️  ALERTA DE IP: O IP resolvido (192.168.31.x) parece incorreto para este cluster.")
             print("    O cluster geralmente usa 192.168.1.x (LoadBalancer).")
             print("    Verifique seu arquivo /etc/hosts ou DNS.")
    
    print("\n=== Conclusão ===")
    if not url_ok:
        print("❌ A Connection String está inválida devido à senha não codificada.")
        print("   SUGESTÃO: Mude para:")
        print("   amqp://admin:Admin%40123@rabbitmq.home.arpa:5672/")
    elif resolved_ip and not tcp_ok:
        print("❌ Problema de Rede: Não foi possível conectar na porta TCP.")
        print("   Verifique se o IP está correto e se não há Firewall.")

if __name__ == "__main__":
    main()
