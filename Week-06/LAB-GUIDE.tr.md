# Hafta 6 Lab: İlk Kubernetes kümeniz (tarayıcıda)

**Süre:** 35 dakika, partnerle çalışın. **İngilizce sürüm:** `LAB-GUIDE.md`.

Bu lab için hiçbir şey kurmuyorsunuz. Tarayıcı sekmesinde çalışan küçük bir Kubernetes kümesi kullanıyorsunuz. Buradaki her komut yapıştırılabilir, yani oturumunuz biterse hızlıca baştan başlayabilirsiniz.

**Çalışma kuralı:** *önce tahmin et, sonra çalıştır.* Her deneyden önce partnerinize ne olacağını düşündüğünüzü söyleyin. Yanlış tahmin bir şey kaybettirmez.

## Bölüm 0: Bir küme edinin (5 dakika, molada yapın)

**Seçenek A (önerilen): Killercoda.**

1. <https://killercoda.com> adresine gidin ve ücretsiz hesap açın.
2. Kubernetes playground’u açın. <https://killercoda.com/kubernetes> sayfası onu listeler, Playgrounds sayfasında daha fazlası var.
3. Tarayıcıda bir terminal açılır. Her şey için `kubectl` komutunu kullanırsınız.

Bilmeniz gerekenler: ücretsiz oturum **bir saat** sürer ve sekmeyi kapattığınızda ortam **silinir**. Orada yaptığınız hiçbir şey kendi bilgisayarınıza dokunmaz.

**Seçenek B (A işe yaramazsa):**

- KodeKloud Kubernetes playground (ücretsiz giriş, 60 dakikalık oturum): <https://kodekloud.com/playgrounds/playground-kubernetes-single-node-latest>
- iximiuz Labs, “Kubernetes Cluster” playground (ücretsiz hesap): <https://labs.iximiuz.com/>

**Seçenek C (kendi bilgisayarınızda):** Docker Desktop’ta Kubernetes anahtarı var (Settings, Kubernetes, etkinleştirin). Ya da [kind](https://kind.sigs.k8s.io/) kurup `kind create cluster` çalıştırın. Ayrıca `kubectl` gerekir.

Çalıştığını kontrol edin:

```bash
kubectl get nodes
```

En az bir node görmelisiniz ve `STATUS` sütununda **Ready** yazmalı. Öyleyse bölüm 0 bitti.

## Bölüm 1: Etrafa bakın (3 dakika)

```bash
kubectl cluster-info
kubectl get nodes -o wide
kubectl get pods -A
```

- `-A` “tüm namespace’ler” demek. Küme kendi sistem Pod’larını zaten çalıştırıyor. Bunlar slaytlardaki “beynin” parçaları.

**Düşünün:** bu Pod’lardan hangilerini kümenin parçaları slaytından tanıdınız?

## Bölüm 2: Bir uygulama dağıtın (8 dakika)

nginx’in üç kopyasıyla bir Deployment oluşturun, sonra Pod’lara bakın.

```bash
kubectl create deployment web --image=nginx:1.27 --replicas=3
kubectl get deployments
kubectl get pods -o wide
```

Üç Pod’un da `Running` olmasını bekleyin (ilk seferde imaj indirilmesi gerekir, bu yüzden bir süre `ContainerCreating` görmek normaldir).

- **Tahmin:** `IP` sütununda kaç farklı IP adresi göreceksiniz?

Şimdi Pod’lara bir Service ile sabit bir isim verin:

```bash
kubectl expose deployment web --port=80
kubectl get service web
```

Service’i **isimle** çağırın, kümenin içindeki geçici bir Pod’dan (Hafta 5’in aynısı: IP değil isim):

```bash
kubectl run tmp --rm -it --image=busybox:1.37 --restart=Never -- wget -qO- http://web
```

nginx karşılama sayfasının HTML’ini görmelisiniz. Geçici Pod komut bitince silinir.

**Düşünün:** `http://web` neden çalışıyor? Bu size Hafta 5’ten hangi fikri hatırlatıyor?

## Bölüm 3: Bozun, ölçekleyin, güncelleyin (12 dakika)

### 3.1 Bir Pod’u silin

- **Tahmin:** üç Pod’dan birini siliyorsunuz. Geri gelir mi? Aynı isimle mi?

İkinci bir terminal sekmesi açın (ya da sonra `--watch` kullanın) ve Pod isimlerine bakın. Sonra:

```bash
kubectl get pods
kubectl delete pod POD-ADI         # listeden gerçek bir isim kopyalayın
kubectl get pods
```

(`POD-ADI` yerine gerçek bir isim yazın. İsimler `web-5d8c7f9b4-x2k9p` gibi görünür.)

`AGE` sütununa bakın. Hangi Pod yeni?

### 3.2 Ölçekleyin

```bash
kubectl scale deployment web --replicas=5
kubectl get pods
kubectl scale deployment web --replicas=3
```

### 3.3 Durmadan yeni sürüme güncelleyin

```bash
kubectl set image deployment/web nginx=nginx:1.28
kubectl rollout status deployment/web
kubectl get pods
```

`nginx=nginx:1.28` içindeki ilk `nginx` **container adı**, ikinci kısım imajdır.

### 3.4 Bilerek hata yapın, sonra geri alın

- **Tahmin:** var olmayan bir imaj etiketiyle güncelliyorsunuz. Tüm servis durur mu?

```bash
kubectl set image deployment/web nginx=nginx:no-such-tag
kubectl get pods
```

10 ila 20 saniye bekleyin ve `kubectl get pods` komutunu tekrar çalıştırın. Bazı yeni Pod’lar `ErrImagePull` veya `ImagePullBackOff` gösterir. Kaç eski Pod hâlâ `Running`?

Neden başarısız olduğunu okuyun:

```bash
kubectl describe pod POD-ADI       # başarısız Pod’lardan birini kullanın, en alttaki Events kısmını okuyun
```

Geri dönün:

```bash
kubectl rollout undo deployment/web
kubectl rollout status deployment/web
kubectl get pods
```

**Düşünün:** Hafta 4’teki hangi alışkanlık (Dockerfile’daki `FROM` satırı) geri almayı kolaylaştırıyor?

## Bölüm 4: Güvenli Pod’lar, PHP dersi (8 dakika)

Bu haftaki PHP sorunu şunu gösterdi: içeri giren saldırgan, uygulamanın yapabildiğini yapabilir. Burada aynı programı çalıştıran iki Pod’u karşılaştırıyoruz.

Dosyaları oluşturun (bloğun tamamını birden kopyalayın):

```bash
cat <<'EOF' > rootpod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: rootpod
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sleep", "3600"]
EOF

cat <<'EOF' > safepod.yaml
apiVersion: v1
kind: Pod
metadata:
  name: safepod
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sleep", "3600"]
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
        seccompProfile:
          type: RuntimeDefault
EOF

kubectl apply -f rootpod.yaml -f safepod.yaml
kubectl get pods
```

İki dosya da ders reposundaki `manifests/` klasöründe bulunuyor.

**Tahmin** (partnerinizle konuşun), her komut için: `safepod` üzerinde çalışır mı?

```bash
kubectl exec rootpod -- id
kubectl exec safepod -- id
kubectl exec safepod -- touch /hello
kubectl exec rootpod -- touch /hello
kubectl exec safepod -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

Gördüklerinizi not edin. Son komut sürpriz: sertleştirilmiş Pod hâlâ `token` adlı bir dosyayı okuyabiliyor. Bu, Pod’un kümenin beyniyle konuşmak için varsayılan olarak aldığı anahtar. Çoğu uygulamanın buna ihtiyacı yok. Şimdi onsuz üçüncü bir Pod oluşturun:

```bash
cat <<'EOF' > safepod-nosa.yaml
apiVersion: v1
kind: Pod
metadata:
  name: safepod-nosa
spec:
  automountServiceAccountToken: false
  containers:
    - name: app
      image: busybox:1.37
      command: ["sleep", "3600"]
      securityContext:
        runAsNonRoot: true
        runAsUser: 10001
        runAsGroup: 10001
        allowPrivilegeEscalation: false
        readOnlyRootFilesystem: true
        capabilities:
          drop: ["ALL"]
        seccompProfile:
          type: RuntimeDefault
EOF

kubectl apply -f safepod-nosa.yaml
kubectl exec safepod-nosa -- ls /var/run/secrets/kubernetes.io/serviceaccount
```

Şimdi son komut “No such file or directory” hatasıyla başarısız olmalı.

**Düşünün (ve notlarınıza yazın):** derste konuştuğumuz beş sorudan (kullanıcı, dosyalar, diğer servisler, araçlar, host) `safepod` ayarları hangilerini iyileştirdi? Hangilerini **değiştirmedi**? Bu `safepod`’u “güvenli” yapar mı?

## Bölüm 5 (ek görev): Aynı şey bir YAML dosyası olarak

Erken bitirirseniz, bölüm 2’yi dosyalarla yapın, tıpkı Compose’un `compose.yaml` kullandığı gibi. Benzer dosyalar `manifests/` içinde (onlar `web` adını kullanıyor, burada `web2` kullanıyoruz):

```bash
cat <<'EOF' > deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: web2
spec:
  replicas: 3
  selector:
    matchLabels:
      app: web2
  template:
    metadata:
      labels:
        app: web2
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
EOF

kubectl apply -f deployment.yaml
kubectl get pods
```

Şimdi dosyadaki `replicas: 3` değerini `replicas: 4` yapın (`nano deployment.yaml`), kaydedin ve `kubectl apply -f deployment.yaml` komutunu tekrar çalıştırın. Ne değişti? Hafta 5’ten bildiğiniz `docker compose up` ile karşılaştırın.

(Neden `web2`? Bölüm 2’deki `web` Deployment’ı ile çakışmasın diye.)

## Temizlik

```bash
kubectl delete deployment web web2
kubectl delete service web
kubectl delete pod rootpod safepod safepod-nosa
```

Bir isim yoksa hata alırsınız, sorun değil. Killercoda kullandıysanız sekmeyi kapatmanız da yeterli: tüm ortam silinir.

## Komut özeti

| Komut | Ne yapar |
|---|---|
| `kubectl get nodes` / `pods` / `deployments` / `service` | Nesneleri listeler. Daha çok sütun için `-o wide`, tüm namespace’ler için `-A` |
| `kubectl create deployment AD --image=IMG --replicas=N` | Deployment oluşturur |
| `kubectl expose deployment AD --port=80` | Önüne bir Service koyar |
| `kubectl scale deployment AD --replicas=N` | Kopya sayısını değiştirir |
| `kubectl set image deployment/AD CONTAINER=IMG` | Yeni imajı yayar |
| `kubectl rollout status` / `undo` / `history` | Güncellemeyi izler, geri alır veya listeler |
| `kubectl describe pod AD` | Ayrıntılar ve **Events** (bir şey başarısız olursa bunları okuyun) |
| `kubectl logs AD` | Container’ın çıktısı |
| `kubectl exec AD -- KOMUT` | Pod içinde komut çalıştırır |
| `kubectl apply -f DOSYA` / `delete -f DOSYA` | YAML dosyasından oluşturur veya günceller / siler |

## Sorun giderme

| Ne görüyorsunuz | Şunu deneyin |
|---|---|
| Oturum bitti | Yenisini başlatın, komutları tekrar yapıştırın |
| Pod `Pending` veya `ContainerCreating` | 30 saniye bekleyin, sonra `kubectl describe pod AD` ile Events kısmını okuyun |
| `ImagePullBackOff` | İmaj adında ve etikette yazım hatası var mı bakın |
| Terminalde yapıştırma çalışmıyor | Ctrl+Shift+V deneyin veya sağ tıklayıp yapıştırın |
| `command not found: kubectl` | Kendi terminalinizdesiniz. Playground terminalini kullanın |
| `The connection to the server ... was refused` | Küme henüz hazır değil (bir dakika bekleyin) ya da yanlış terminaldesiniz |
| İsim zaten var (`AlreadyExists`) | Komutu iki kez çalıştırdınız. Sorun değil, ya da önce silip tekrar çalıştırın |

## Düşünme soruları (her biri için 2-3 cümle yazın)

1. Pod’u sildikten sonra neden geri geldi? *İstenen durum (desired state)* ve *gerçek durum (actual state)* kelimelerini kullanın.
2. Bir Pod değiştirildiğinde yeni isim ve yeni IP alır. Diğer servisler onu yine de nasıl bulur?
3. Hatalı güncelleme sırasında uygulama neden çalışmaya devam etti?
4. `safepod` ayarlarının sınırladığı iki şeyi ve sınırlamadığı bir şeyi söyleyin.
5. Hafta 5’teki hangi Compose fikri Service’e karşılık geliyor? Hangisi Deployment’a?
