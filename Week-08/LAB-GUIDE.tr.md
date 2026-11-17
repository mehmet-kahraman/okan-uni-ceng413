# Hafta 8 Lab: Bir pipeline kur, sonra yeşile çevir

**Süre:** 40 dakika. **İkişerli çalışın.** **Nerede:** tarayıcıda bir Killercoda Ubuntu playground (https://killercoda.com/playgrounds). Bilgisayarınıza bir şey kurmanız gerekmez.
**Bugün teslim yok.** Bu lab notlandırılmaz.

## Ne yapacaksınız

Altı kasıtlı sorunu olan küçük bir Flask uygulaması ve bir CI sunucusunun çalıştırdığı aşamaları çalıştıran `pipeline.sh` betiği alacaksınız: lint, test, SAST, secret taraması, bağımlılık taraması, Dockerfile kuralları. Başta **kalite kapısı (quality gate) kırmızı**. Yeşil olana kadar aşamaları tek tek düzeltirsiniz.

**Labın kuralı: önce tahmin.** Bir aşamayı çalıştırmadan önce eşinize yüksek sesle söyleyin: geçer mi, kalır mı, neden?

| Aşama | Araç | Hangi soruya cevap verir |
|---|---|---|
| lint | ruff | Kod temiz mi (kullanılmayan import ve değişkenler)? |
| test | pytest + coverage | Kod testlerin dediğini yapıyor mu? Yeterli kısmı test edilmiş mi? |
| sast | bandit | Kaynak kodda riskli kalıplar var mı? |
| secrets | detect-secrets | Biri anahtar veya parola commit etmiş mi? |
| deps | pip-audit | Kütüphanelerimizde bilinen açıklar var mı? |
| docker | iki küçük kural | Base image sabitlenmiş mi? Non-root çalışıyor mu? |

## Bölüm 0: Hazırlık (5 dk)

Bir Killercoda Ubuntu playground açın. Sonra:

```bash
python3 --version
python3 -m venv .venv-lab && . .venv-lab/bin/activate
```

`venv` yoksa: `apt-get update && apt-get install -y python3-venv`, sonra ikinci satırı tekrarlayın.

Projeyi oluşturun. Aşağıdaki uzun blok tüm dosyaları `ci-lab` klasörüne yazar (hepsini kopyalayıp bir kerede yapıştırın):

```bash
#!/usr/bin/env bash
# Creates the Week 8 lab project in ./ci-lab (a small Flask app with planted problems).
set -e
mkdir -p ci-lab && cd ci-lab
mkdir -p .github/workflows
cat > .github/workflows/ci.yml <<'LAB_EOF'
# The same stages as pipeline.sh, now on a CI server (GitHub Actions).
name: CI

on:
  push:
  pull_request:

permissions:
  contents: read

jobs:
  quality:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - uses: actions/setup-python@v5
        with:
          python-version: "3.13"
          cache: pip
      - name: Install dependencies
        run: pip install -r requirements.txt -r requirements-dev.txt
      - name: Lint
        run: ./pipeline.sh lint
      - name: Test
        run: ./pipeline.sh test
      - name: SAST
        run: ./pipeline.sh sast
      - name: Secret scan
        run: ./pipeline.sh secrets
      - name: Dependency scan
        run: ./pipeline.sh deps
      - name: Dockerfile rules
        run: ./pipeline.sh docker

  build:
    needs: quality
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v4
      - name: Build image
        run: docker build -t ci-lab:${{ github.sha }} .
LAB_EOF
cat > .gitignore <<'LAB_EOF'
.venv/
__pycache__/
.pytest_cache/
.ruff_cache/
.coverage
.env
LAB_EOF
cat > Dockerfile <<'LAB_EOF'
FROM python:latest
WORKDIR /app
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
CMD ["gunicorn", "-b", "0.0.0.0:8000", "app:app"]
LAB_EOF
cat > app.py <<'LAB_EOF'
"""CI lab app: a tiny Flask service. It has a few planted problems on purpose."""
import hashlib
import os
import sys

from flask import Flask, jsonify, request

app = Flask(__name__)

API_KEY = "AKIAIOSFODNN7EXAMPLE"


@app.get("/health")
def health():
    started = True
    return jsonify(status="ok")


@app.get("/square")
def square():
    try:
        n = int(request.args.get("n", ""))
    except ValueError:
        return jsonify(error="n must be an integer"), 400
    return jsonify(n=n, square=n * 2)


@app.get("/fingerprint")
def fingerprint():
    text = request.args.get("text", "")
    return jsonify(sha=hashlib.md5(text.encode()).hexdigest())


@app.get("/whoami")
def whoami():
    return jsonify(has_key=bool(API_KEY), env=os.environ.get("APP_ENV", "dev"))


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=8000, debug=True)
LAB_EOF
cat > pipeline.sh <<'LAB_EOF'
#!/usr/bin/env bash
# A tiny local pipeline: the same stages a CI server would run.
# Every stage runs; the build FAILS at the end if any stage failed (the quality gate).
# Usage: ./pipeline.sh            (all stages)
#        ./pipeline.sh lint test  (only some stages)

set -u
cd "$(dirname "$0")" || exit 1

FAILED=()
RESULTS=()

stage() {  # stage NAME COMMAND...
  local name="$1"; shift
  echo
  echo "=== STAGE: $name ==="
  if "$@"; then
    RESULTS+=("PASS  $name")
  else
    RESULTS+=("FAIL  $name")
    FAILED+=("$name")
  fi
}

want() {  # want NAME: true if no stage list was given, or NAME is in it
  [ "$#" -eq 1 ] && return 0
  local n="$1"; shift
  for s in "$@"; do [ "$s" = "$n" ] && return 0; done
  return 1
}

stage_lint()    { ruff check . ; }
stage_test()    { python -m pytest --cov=app --cov-report=term-missing --cov-fail-under=80 -q ; }
stage_sast()    { bandit -q -r app.py -ll -f custom --msg-template "{relpath}:{line}  {test_id} {severity}: {msg}" ; }
stage_secrets() {
  # detect-secrets always exits 0, so we read its report and fail if anything was found.
  detect-secrets scan --all-files --exclude-files '(\.venv|\.git|\.pytest_cache|\.ruff_cache|__pycache__|tests)/.*' . > /tmp/ci-secrets.json || return 1
  python - <<'PY'
import json, sys
found = json.load(open("/tmp/ci-secrets.json"))["results"]
for path, items in found.items():
    for item in items:
        print(f"{path}:{item['line_number']}  {item['type']}")
sys.exit(1 if found else 0)
PY
}
stage_deps()    { pip-audit -r requirements.txt ; }
stage_docker()  {
  # Two cheap rules for the Dockerfile: a pinned base image, and a non-root user.
  local ok=0
  if grep -Eq '^FROM +[^ ]+:latest|^FROM +[^: ]+( |$)' Dockerfile; then
    echo "Dockerfile: base image is not pinned to a version tag"; ok=1
  fi
  if ! grep -Eq '^USER +[^ ]+' Dockerfile; then
    echo "Dockerfile: no USER line, the container runs as root"; ok=1
  fi
  return $ok
}

ALL=(lint test sast secrets deps docker)
for s in "${ALL[@]}"; do
  if want "$s" "$@"; then stage "$s" "stage_$s"; fi
done

echo
echo "=== SUMMARY ==="
printf '%s\n' "${RESULTS[@]}"
if [ "${#FAILED[@]}" -gt 0 ]; then
  echo
  echo "QUALITY GATE: FAILED (${#FAILED[@]} stage(s): ${FAILED[*]})"
  exit 1
fi
echo
echo "QUALITY GATE: PASSED"
LAB_EOF
cat > pytest.ini <<'LAB_EOF'
[pytest]
pythonpath = .
testpaths = tests
LAB_EOF
cat > requirements-dev.txt <<'LAB_EOF'
# Tools for the pipeline (not shipped in the image). Left unpinned on purpose for the lab.
pytest
pytest-cov
ruff
bandit
pip-audit
detect-secrets
LAB_EOF
cat > requirements.txt <<'LAB_EOF'
flask==3.0.0
gunicorn==23.0.0
LAB_EOF
mkdir -p tests
cat > tests/test_app.py <<'LAB_EOF'
import pytest

import app as app_module


@pytest.fixture()
def client():
    return app_module.app.test_client()


def test_health(client):
    assert client.get("/health").get_json() == {"status": "ok"}


def test_square(client):
    assert client.get("/square?n=7").get_json() == {"n": 7, "square": 49}


def test_square_rejects_text(client):
    assert client.get("/square?n=abc").status_code == 400


def test_fingerprint_is_stable(client):
    a = client.get("/fingerprint?text=hi").get_json()["sha"]
    b = client.get("/fingerprint?text=hi").get_json()["sha"]
    assert a == b


def test_whoami(client):
    assert "has_key" in client.get("/whoami").get_json()
LAB_EOF
chmod +x pipeline.sh
echo "Created ci-lab. Next: cd ci-lab"
```

Sonra uygulama kütüphanelerini ve pipeline araçlarını kurun:

```bash
cd ci-lab
pip install -r requirements.txt -r requirements-dev.txt
```

Dosyalara bakın: `ls -la` ve `cat app.py`. Henüz bir şey düzeltmeyin.

## Bölüm 1: Pipeline'ı çalıştırın ve kırmızıyı okuyun (5 dk)

**Tahmin:** altı aşamadan kaçı kalacak? Sayınızı yazın.

```bash
./pipeline.sh
```

Altta **SUMMARY** bölümünü okuyun. Betik *tüm* aşamaları çalıştırır, sonunda herhangi biri kaldıysa başarısız olur. Bu **kalite kapısıdır**: yeşil yoksa yayın yok.

Tek bir aşamayı çalıştırabilirsiniz, örneğin `./pipeline.sh lint`, ya da birkaçını: `./pipeline.sh lint test`.

## Bölüm 2: Aşamaları düzeltin (20 dk)

Bu sırayla ilerleyin. Her aşamada: önce mesajı okuyun, kendiniz düzeltmeyi deneyin, ancak takılırsanız ipucunu açın. Her düzeltmeden sonra yalnızca o aşamayı çalıştırın.

### 2a. lint

`./pipeline.sh lint`, `app.py` içinde kullanılmayan bir import ve bir değişken bildirir.

<details><summary>İpucu (çözüm)</summary>

```bash
sed -i '/^import sys$/d;/started = True/d' app.py
./pipeline.sh lint
```
</details>

### 2b. test

`./pipeline.sh test` başarısız bir test gösterir. **Farkı okuyun.** Hangisi yanlış: test mi, kod mu?

<details><summary>İpucu (çözüm)</summary>

Test doğru: 7'nin karesi 49. Kod 2 ile çarpıyor.

```bash
sed -i 's/square=n \* 2/square=n * n/' app.py
./pipeline.sh test
```
</details>

Coverage tablosuna bakın: satırların %80'inden azı kapsanırsa pipeline yine kalır. Coverage, testlerin kodun ne kadarını *çalıştırdığını* söyler, testlerin ne kadar iyi olduğunu değil.

### 2c. sast

`./pipeline.sh sast`, B324 gibi bir kimlikle riskli kalıpları listeler. Neden önemli olduğunu merak ederseniz kimliği bandit dokümanında arayın.

Burada iki sorun var: zayıf bir hash (MD5) ve tüm arayüzlere bağlanan bir Flask debug sunucusu. Debug sunucusu yalnızca geliştirme içindir; container'da gunicorn kullanırız.

<details><summary>İpucu (çözüm)</summary>

```bash
sed -i 's/hashlib.md5/hashlib.sha256/' app.py
sed -i '/^if __name__/,$d' app.py
./pipeline.sh sast
```
</details>

### 2d. secrets

`./pipeline.sh secrets`, `app.py` içinde bir anahtar bulur. **Eşinizle tartışın:** bu gerçek bir anahtar olsaydı ve Git'e çoktan gönderilmiş olsaydı, satırı silmek yeterli olur muydu? (Yansıtma sorusu 3'e bakın.)

<details><summary>İpucu (çözüm)</summary>

Anahtar koddan değil, ortamdan gelmeli.

```bash
sed -i 's|^API_KEY = .*|API_KEY = os.environ.get("API_KEY", "")|' app.py
./pipeline.sh secrets
```
</details>

### 2e. deps

`./pipeline.sh deps`, sabitlediğimiz Flask sürümündeki bilinen açıkları listeler. "Fix Versions" sütunu hangi sürümü kullanmanız gerektiğini söyler. (İnternet gerekir; Killercoda'da var.)

<details><summary>İpucu (çözüm)</summary>

```bash
sed -i 's/flask==3.0.0/flask==3.1.3/' requirements.txt
pip install -r requirements.txt
./pipeline.sh deps
```

Daha yeni bir düzeltme sürümü listelenmişse onu kullanın ve eğitmene söyleyin: liste zamanla değişir.
</details>

### 2f. docker

`./pipeline.sh docker`, Dockerfile'da iki kuralı kontrol eder: base image'ın sürüm etiketi var (`latest` değil) ve bir `USER` satırı var.

<details><summary>İpucu (çözüm)</summary>

```bash
sed -i 's|^FROM python:latest|FROM python:3.13-slim|' Dockerfile
sed -i 's|^CMD|RUN useradd --create-home appuser\nUSER appuser\nCMD|' Dockerfile
cat Dockerfile
./pipeline.sh docker
```
</details>

## Bölüm 3: Yeşil kapı (3 dk)

```bash
./pipeline.sh
```

`QUALITY GATE: PASSED` görmek istiyorsunuz. Bir aşama hâlâ kırmızıysa mesajını yeniden okuyun.

## Bölüm 4: Aynı pipeline bir CI sunucusunda (5 dk)

Workflow dosyasını açın ve eşinizle birlikte okuyun:

```bash
cat .github/workflows/ci.yml
```

Şu fikirleri bulun: **tetikleyici** (`on:`), **job** ve **step**'leri, **permissions** satırı, `needs: quality` (image yalnızca quality job'ı yeşil olduktan sonra build edilir). Bu dosya GitHub'daki bir Git deposunda `.github/workflows/` klasörüne konur. Killercoda GitHub olmadığı için bugün çalıştırmıyoruz.

**Tedarik zinciri: malzeme listesi (SBOM) üretin.** SBOM, yazılımınızın içindeki her kütüphanenin listesidir.

```bash
pip-audit -r requirements.txt -f cyclonedx-json -o sbom.json
python3 -c "import json; d=json.load(open('sbom.json')); print(len(d['components']), 'components'); [print(' ', c['name'], c['version']) for c in d['components']]"
```

**2** kütüphane sabitlemiştiniz. Kaç bileşen çıktı? Aradaki fark, kütüphanelerinizin beraberinde getirdiği kütüphanelerdir.

## Bölüm 5: Temizlik

Playground'u kapatın. Başka bir şey gerekmez.

## Yansıtma soruları (her biri için kendiniz 2 veya 3 cümle yazın)

1. Hangi aşamanın kalacağını tahmin ettiniz, hangisi sizi şaşırttı?
2. Bir takım arkadaşı bandit'i susturmak için `# nosec` ekliyor. Bu ne zaman kabul edilebilir, pull request'te ne sormalısınız?
3. Anahtar, tarama çalışmadan önce Git'e gönderildi. Satırı silmek neden yetmez? İlk önce ne yaparsınız?
4. Pipeline'ınız 20 dakika sürüyor. Hangi aşamaları her push'ta, hangilerini yalnızca yayından önce çalıştırırsınız?
5. Coverage %100. Bu, uygulamada hata olmadığı anlamına gelir mi?

## Sorun giderme

- **`pip: command not found` veya "externally managed environment":** Bölüm 0'daki sanal ortamı kullanın (`. .venv-lab/bin/activate`).
- **`./pipeline.sh: Permission denied`:** `chmod +x pipeline.sh`.
- **`ruff`, `bandit` veya başka bir araç "not found":** sanal ortam aktif değil. `ci-lab` içindeyken `. ../.venv-lab/bin/activate` çalıştırın.
- **`deps` aşaması ağ hatasıyla kalıyor:** playground'un şu an interneti yok. Bir dakika bekleyip tekrar deneyin ya da eğitmene söyleyin.
- **Dosyaları bozdunuz:** kurulum bloğunu yeni boş bir klasörde tekrar çalıştırın.

## Komut özeti

| Komut | Ne yapar |
|---|---|
| `./pipeline.sh` | tüm aşamaları ve kalite kapısını çalıştırır |
| `./pipeline.sh lint test` | yalnızca bazı aşamaları çalıştırır |
| `ruff check .` | lint |
| `python -m pytest --cov=app` | coverage ile testler |
| `bandit -r app.py -ll` | SAST, yalnızca orta ve yüksek |
| `pip-audit -r requirements.txt` | bağımlılıklardaki bilinen açıklar |
| `pip-audit -r requirements.txt -f cyclonedx-json -o sbom.json` | SBOM |
