import urllib.parse
import sys

def test_url_parsing(url):
    print(f"Testing URL: {url}")
    try:
        parsed = urllib.parse.urlparse(url)
        print(f"  Scheme: {parsed.scheme}")
        print(f"  Username: {parsed.username}")
        print(f"  Password: {parsed.password}")
        print(f"  Hostname: {parsed.hostname}")
        print(f"  Port: {parsed.port}")
        
        if parsed.password == "Admin@123":
            print("\n✅ SUCCESS: Password parsed correctly!")
        else:
            print(f"\n❌ ERROR: Password parsed incorrectly. Expected 'Admin@123', got '{parsed.password}'")
            print("   The '@' character in the password is confusing the URL parser.")
            
    except Exception as e:
        print(f"❌ Exception parsing URL: {e}")

print("--- Cenário 1: URL Original ---")
url_original = "amqp://admin:Admin@123@rabbitmq.home.arpa:5672/"
test_url_parsing(url_original)

print("\n--- Cenário 2: URL Corrigida (Encoded) ---")
url_fixed = "amqp://admin:Admin%40123@rabbitmq.home.arpa:5672/"
test_url_parsing(url_fixed)
