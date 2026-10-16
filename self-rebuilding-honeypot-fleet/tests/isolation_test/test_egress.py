# Runs INSIDE the honeypot network. Exit 0 = isolation OK (internet blocked). Exit 1 = LEAK.
import sys
import urllib.request

targets = ["https://example.com", "https://1.1.1.1"]
leaked = False

for url in targets:
    try:
        urllib.request.urlopen(url, timeout=5)
        print("LEAK: reached", url)
        leaked = True
    except Exception as e:
        print("blocked:", url, "->", type(e).__name__)

if leaked:
    sys.exit(1)

print("isolation OK")
sys.exit(0)
