# Hafta 4 Lab: Build, Run, Break, Fix

**Ders:** CENG413 · **Konu:** Docker temelleri · **Süre:** yaklaşık 35 dakika · **İstersen ikili çalışabilirsin.**

Bu labın sonunda şunları yapmış olacaksın:

- Bir Dockerfile'dan Docker imajı build etmek,
- İmajı container olarak çalıştırıp endpoint'lerini çağırmak,
- Build cache'in zaman kazandırdığını görmek,
- Veriyi bilerek kaybetmek, sonra volume ile kalıcı hale getirmek,
- (bonus) Bir container'dan diğerini isimle çağırmak.

> **Kural:** Yardım istemeden önce hata mesajını oku. Hataların çoğu neyin yanlış olduğunu zaten söyler.

## 0. Kurulumunu kontrol et

Bir terminal aç (Windows'ta PowerShell) ve çalıştır:

```bash
docker version
```

Hem *Client* hem *Server* bölümünü görmelisin. Server yoksa Docker Desktop'ı başlat ve "running" yazana kadar bekle.

> **Windows notu:** PowerShell'de `curl` başka bir komutun takma adıdır. `curl.exe` kullan ya da adresi tarayıcıda aç.

## 1. Kodu al

Clone ettiğin klasöre gir (içinde `app.py` ve iki Dockerfile olan klasör; adı repo adıdır):

```bash
cd <repo-klasoru>
```

Dosyalara bak. Hangisi uygulama? Hangileri Dockerfile? `.dockerignore` ne işe yarıyor?

Uygulama üç endpoint'i olan küçük bir web servisi:

| Endpoint | Ne yapar | Stateless mı? |
|---|---|---|
| `/health` | `{"status": "ok"}` döner | evet |
| `/greet?name=Ada` | selamlama döner | evet |
| `/visit` | ziyaret sayar, bir dosyaya yazar | **hayır, bilerek** |

## 2. Yavaş sürümü build et (Dockerfile.v1)

```bash
docker build -f Dockerfile.v1 -t lab:v1 .
```

- `-f` hangi Dockerfile'ın kullanılacağını, `-t` imaja isim:etiket vermeyi, `.` build context'i belirtir.
- Ne kadar sürdüğünü not et (ilk build çok şey indirir).

İmajı kontrol et:

```bash
docker images lab
```

## 3. Çalıştır ve çağır

```bash
docker run -d --name lab1 -p 8000:8000 lab:v1
```

Tarayıcıda aç ya da curl kullan:

```bash
curl http://localhost:8000/health
curl "http://localhost:8000/greet?name=Adin"
```

Log'lara ve çalışan container'a bak:

```bash
docker ps
docker logs lab1
```

Temizle:

```bash
docker rm -f lab1
```

> **Port zaten kullanımda mı?** Soldaki sayıyı değiştir: `-p 8001:8000` ve `localhost:8001` kullan.

## 4. Cache'i hisset (adil bir test)

Amaç: iki Dockerfile'ı **adil** karşılaştırmak. Aynı makine, aynı base imajlar, aynı kod değişikliği. Önce iki Dockerfile'ı yan yana aç. Ne farklı? (İlk satıra, `COPY` ve `RUN` sırasına ve kullanıcıya bak.)

**4a. Başlangıç ölçümü: ikisini de sıfırdan build et.** `--no-cache` her adımı yeniden çalıştırır, böylece iki build de aynı noktadan başlar. Base imajlar bilgisayarında zaten var, yani bu ölçüm Wi-Fi'ı değil Dockerfile'ı ölçer.

macOS / Linux:

```bash
time docker build --no-cache -f Dockerfile.v1 -t lab:v1 .
time docker build --no-cache -t lab:v2 .
```

Windows PowerShell:

```powershell
Measure-Command { docker build --no-cache -f Dockerfile.v1 -t lab:v1 . | Out-Default }
Measure-Command { docker build --no-cache -t lab:v2 . | Out-Default }
```

İki süreyi aşağıdaki sonuç tablosuna yaz.

**4b. Kodu değiştir, sonra ikisini de yeniden build et.** `app.py` dosyasına bir yorum satırı ekle. Bu, uygulamayı bozmadan dosyayı değiştirir.

macOS / Linux:

```bash
echo "# change 1" >> app.py
```

Windows PowerShell:

```powershell
Add-Content app.py "# change 1"
```

İkisini yeniden build et. `--progress=plain` her adımı yazdırır, böylece hangi adımların `CACHED` dediğini görürsün:

```bash
time docker build --progress=plain -f Dockerfile.v1 -t lab:v1 .
time docker build --progress=plain -t lab:v2 .
```

(PowerShell'de her build'i yukarıdaki gibi `Measure-Command { ... | Out-Default }` içine al.)

Her build'in çıktısına bak:

- Hangi adımlar `CACHED` yazıyor?
- Hangi build'de `pip install` yeniden çalıştı?

Daha çok kanıt ister misin? 4b'yi `# change 2` ile tekrarla.

**4c. İmajları karşılaştır.**

```bash
docker image ls lab
docker history lab:v1
docker history lab:v2
```

Eğitmenin laptopundan örnek çıktı:

```
IMAGE      ID             DISK USAGE   CONTENT SIZE
lab:v1     a43a57dfbd87   1.63GB       407MB
lab:v2     274e7f106ce6   226MB        49.1MB
```

Aynı uygulama; v2 diskte yaklaşık **7 kat küçük** (indirme boyutu ise 8 kat az). Dockerfile'da sadece birkaç satır farklı. *Disk usage* diskte kapladığı yerdir. *Content size* bir registry'den indireceğin ya da yükleyeceğin sıkıştırılmış veridir. Eski Docker sürümleri tek bir `SIZE` sütunu gösterir.

**Sonuçlarını doldur:**

| Test | v1 (`Dockerfile.v1`) | v2 (`Dockerfile`) |
|---|---|---|
| 4a başlangıç, `--no-cache` süresi | | |
| 4b kod değişikliğinden sonra süre | | |
| 4b `CACHED` yazan adımlar | | |
| İmaj boyutu (`docker image ls lab`) | | |

**Ne görmelisin:**

- **Başlangıç (4a):** benzer süreler, çünkü iki build'de de her adım çalışır.
- **Kod değişikliğinden sonra (4b):** v1'de `pip install` yeniden çalışır. v2'de `pip install` adımı `CACHED` yazar.
- **Boyut (4c):** v2 birkaç kat daha küçük.

> **Süre farkı çok büyük değil mi?** Burada normal. Bu uygulamanın sadece iki küçük bağımlılığı var, yeniden kurulum birkaç saniye sürer. Onlarca kütüphanesi olan gerçek bir projede o adım dakikalar sürebilir ve cache hepsini kazandırır. Bu labda en güçlü kanıt `CACHED` satırları ve imaj boyutudur.

**4d. İmajın dışından yapılandırma.** v2'yi bir ortam değişkeniyle çalıştır:

```bash
docker run -d --name lab2 -p 8000:8000 -e APP_GREETING=Merhaba lab:v2
curl "http://localhost:8000/greet?name=Adin"
docker rm -f lab2
```

İmaj değişmedi ama davranış değişti. Container'ları böyle yapılandırırız.

## 5. Veriyi kaybet, sonra koru

**5a. Container'ın içindeki veri.**

```bash
docker run -d --name lab2 -p 8000:8000 lab:v2
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/visit
```

1, 2, 3 görmelisin. Şimdi container'ı sil ve yenisini başlat:

```bash
docker rm -f lab2
docker run -d --name lab2 -p 8000:8000 lab:v2
curl http://localhost:8000/visit
```

Hangi sayıyı alıyorsun? Veri nereye gitti?

**5b. Volume içindeki veri.**

```bash
docker rm -f lab2
docker run -d --name lab3 -p 8000:8000 -v labdata:/data lab:v2
curl http://localhost:8000/visit
curl http://localhost:8000/visit
curl http://localhost:8000/visit
docker rm -f lab3
docker run -d --name lab3 -p 8000:8000 -v labdata:/data lab:v2
curl http://localhost:8000/visit
```

Bu sefer sayı devam eder (4). Container tek kullanımlıktı, veri değildi. Volume'larına bak:

```bash
docker volume ls
```

## 6. Bonus: container'lar isimle konuşuyor

```bash
docker rm -f lab3
docker network create app-net
docker run -d --name api --network app-net lab:v2
docker run --rm --network app-net curlimages/curl curl -s http://api:8000/health
```

İkinci container birinciye `api` ismiyle ulaştı. Hiç port yayınlamadık.

## 7. Temizlik

```bash
docker rm -f api lab1 lab2 lab3
docker network rm app-net
docker volume rm labdata
```

## Düşünme soruları (partnerinle tartış)

1. `requirements.txt` dosyasını neden kodun geri kalanından önce kopyaladık?
2. İmaj ile container arasındaki farkı kendi cümlelerinle anlat.
3. Bu uygulamanın beş kopyasını çalıştırmak istesek `/visit` endpoint'i neden sorun olur? Tasarımı nasıl düzeltirdin?
4. `Dockerfile` (v2), `Dockerfile.v1`'de olmayan kalite kontrol listesindeki hangi maddeleri uyguluyor?
5. Başlangıç süreleri neden benzerdi ama yeniden build süreleri farklıydı? `CACHED` kelimesi sana ne söylüyor?

## Sorun giderme

| Sorun | Olası neden ve çözüm |
|---|---|
| `Cannot connect to the Docker daemon` | Docker Desktop çalışmıyor. Başlat ve bekle. |
| `port is already allocated` | Başka bir program o portu kullanıyor. `-p` içindeki soldaki sayıyı değiştir. |
| `name is already in use` | Eski container duruyor. `docker rm -f <isim>` çalıştır. |
| `permission denied` (Linux) | `sudo` kullan ya da kullanıcını `docker` grubuna ekle. |
| Build çok yavaş | İlk build taban imajı indirir. Sonraki build'ler daha hızlıdır. |
| `curl` çalışmıyor (Windows) | `curl.exe` ya da tarayıcı kullan. |
