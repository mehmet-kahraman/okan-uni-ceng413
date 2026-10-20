# Hafta 5 Lab: İsimle birbirini bulan servisler

**Amaç:** bir uygulamayı ve bir veritabanını iki container olarak çalıştırmak, onları **isimle** konuşturmak ve uygulama container'ının **stateless** olduğunu kanıtlamak.

Süre: yaklaşık 35 dakika. Labda partnerinle çalış (HW-2 bireyseldir). English guide: `LAB-GUIDE.md`.

> Windows PowerShell: `curl` yerine `curl.exe` kullan. Geri kalan her şey aynı.

## 0. Kurulumunu kontrol et

```bash
docker version
docker compose version
```

Client ve Server ile bir Compose sürümü görmelisin. Görmüyorsan elini kaldır.

Lab dosyalarını al (ders reposunun klonuna git):

```bash
git pull
cd Week-05
```

## 1. Neden isimler? (Compose olmadan)

Container'ların IP adresleri değişir. `172.18.0.2` yerine `cache` demek istiyoruz.

**1a. Varsayılan ağ: isim yok.**

```bash
docker run -d --name cache redis:7-alpine
docker run --rm --entrypoint ping redis:7-alpine -c1 -W2 cache
```

İkinci komut `bad address 'cache'` hatasıyla başarısız olur. Container'ı sil:

```bash
docker rm -f cache
```

**1b. Kendi ağın: isimler çalışır.**

```bash
docker network create app-net
docker run -d --name cache --network app-net redis:7-alpine
docker run --rm --network app-net --entrypoint ping redis:7-alpine -c1 cache
```

Şimdi `cache` bir IP adresiyle cevap verir. **Kullanıcı tanımlı bir ağın** içinde küçük bir DNS sunucusu vardır. Temizle:

```bash
docker rm -f cache
docker network rm app-net
```

Partnerine sor: Hafta 4'te tek container olduğunda bu neden sorun değildi?

## 2. Aynı şey Compose ile

`compose.yaml` dosyasını aç. Şunları bul: iki servis (`app`, `cache`), `redisdata` volume'ü, `healthcheck` ve `REDIS_HOST: cache` satırı. Ağ bölümü **yok**. Compose bizim için bir ağ oluşturur.

Her şeyi başlat:

```bash
docker compose up -d --build
docker compose ps
```

**İki** servis görmelisin: `app` ve `cache`, ikisi de `Up`. `docker compose ps` (tıpkı `docker ps` gibi) sadece **çalışan** container'ları gösterir. `app` listede yoksa başlamış ve hemen durmuştur. Nedenini bul:

```bash
docker compose ps -a              # duran container'ları ve exit code'larını da gösterir
docker compose logs app --tail=30 # uygulamanın çıktısı: hata genellikle SON satırlardadır
```

> **Log okumanın iki yolu.** `docker compose logs <servis>` `compose.yaml`'daki **servis adını** kullanır (`app`, `cache`). `docker logs <container>` ise `docker ps -a`'daki **container adını** kullanır (örneğin `week-05-app-1`). İkisi de aynı çıktıyı gösterir. Canlı takip için `-f` ekle, durdurmak için `Ctrl+C`.

Son log satırında `PermissionError: [Errno 13] Permission denied: '/app/app.py'` yazıyorsa en sondaki **Sorun giderme** tablosuna bak.

Uygulamayı üç kez çağır:

```bash
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/whoami
```

`"storage":"redis"` ve sayacın 1, 2, 3 diye gittiğini görmelisin. Uygulama Redis'i `cache` ismiyle buldu.

İçine bak:

```bash
docker compose logs app
docker compose logs cache --tail=5
docker logs <app-container-adi>   # ilk satırla aynı; adı docker compose ps çıktısından al
docker network ls
```

`app` log'unda gunicorn'un başladığını (`Listening at: http://0.0.0.0:8000`), `cache` log'unda Redis'in `Ready to accept connections` mesajını görürsün. Compose'un oluşturduğu `<klasör>_default` adında bir ağ görürsün.

## 3. Uygulamanın stateless olduğunu kanıtla

Hafta 4'te container'ı silince sayaç kayboluyordu. Şimdi durum Redis'te, bir volume içinde. Üç şeyi dene ve her birinden önce **sayacı tahmin et**:

```bash
# A. SADECE app container'ını sil ve yeniden başlat
docker compose rm -sf app
docker compose up -d app
curl http://localhost:8000/visit
docker compose logs app --tail=5   # YENİ bir gunicorn başlangıcı: bu yeni bir container
```

```bash
# B. Her şeyi durdur ve sil, ama volume'leri tut
docker compose down
docker compose up -d
curl http://localhost:8000/visit
```

```bash
# C. Volume dahil her şeyi sil
docker compose down -v
docker compose up -d
curl http://localhost:8000/visit
```

Sonuçlarını buraya yaz:

| Deneme | Tahmin ettiğin sayaç | Gördüğün sayaç |
|---|---|---|
| A. sadece app'i sil | | |
| B. `down` | | |
| C. `down -v` | | |

Ne görmelisin: A sayıma devam eder, B sayıma devam eder, C yeniden 1'den başlar. **Uygulama** container'ı harcanabilir. **Veri** volume'de yaşar.

## 4. Dışarıdan yapılandırma

```bash
APP_GREETING=Merhaba docker compose up -d
curl "http://localhost:8000/greet?name=Adin"
```

(PowerShell: `$env:APP_GREETING="Merhaba"; docker compose up -d`.) İmaj değişmedi ama davranış değişti.

## 5. İsteğe bağlı: kendi registry'n

Bir imaj, başkaları ona ulaşabildiğinde işe yarar. **Registry** imajları saklar. Kendi bilgisayarında küçük bir tane çalıştıracağız.

```bash
docker run -d --name registry -p 5000:5000 registry:2
docker build -t localhost:5000/ceng413/lab:v3 .
docker push localhost:5000/ceng413/lab:v3
curl http://localhost:5000/v2/_catalog
```

Yerel imajı sil ve geri çek:

```bash
docker rmi localhost:5000/ceng413/lab:v3
docker pull localhost:5000/ceng413/lab:v3
```

İsim biçimi: `registry-adresi:port/namespace/imaj:tag`. Docker Hub için `kullanici/imaj:tag`. Docker Hub'a veya GitHub'a push etmek hesap gerektirir, o yüzden onu sadece demo olarak yapıyoruz.

## 6. Temizlik

```bash
docker compose down -v
docker rm -f registry
```

## Düşünme soruları (partnerinle tartış)

1. İsim çözümleme varsayılan ağda neden başarısız oldu, `app-net` üzerinde neden çalıştı?
2. Burada hangi container stateless, hangisi değil? Nereden anlıyorsun?
3. `docker compose down` ile `docker compose down -v` arasındaki fark nedir?
4. `depends_on` ve `condition: service_healthy`, healthcheck'i bekler. "Container başladı" ile "servis hazır" neden aynı şey değil?
5. Uygulamanın üç kopyasını tek bir adresin arkasında çalıştırsan ziyaret sayacı yine doğru olur muydu? Neden?

## Sorun giderme

| Sorun | Ne denemeli |
|---|---|
| `app`, `docker compose ps` çıktısında yok ya da `Exited` | Başlarken çöktü. Exit code için `docker compose ps -a`, sonra `docker compose logs app --tail=30` ve son satırları oku |
| Log `PermissionError: [Errno 13] Permission denied: '/app/app.py'` ile bitiyor | Container `appuser` (root değil) olarak çalışıyor ve dosyalarını okuyamıyor. macOS/Linux: `Week-05` klasöründe `chmod -R a+rX .`, sonra `docker compose up -d --build` |
| `port is already allocated` | Başka bir container 8000 portunu kullanıyor. `docker ps`, sonra `docker rm -f <isim>` |
| `Cannot connect to the Docker daemon` | Docker Desktop'ı başlat ve "running" demesini bekle |
| `/visit` hata veriyor | `docker compose ps`: `cache` healthy mi? `docker compose logs cache` |
| Compose `no configuration file provided` diyor | Yanlış klasördesin. `cd Week-05` |
| `app.py` değişikliği görünmüyor | `docker compose up -d --build` |
