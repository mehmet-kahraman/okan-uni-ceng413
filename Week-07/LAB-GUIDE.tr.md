# Hafta 7 Lab: Yapılandırma, sağlık kontrolleri ve limitler (tarayıcıda)

**Süre:** 45 dakika, bir arkadaşınla birlikte çalış. **İngilizce sürüm:** `LAB-GUIDE.md`.

Geçen haftayla aynı düzen: tarayıcı sekmesinde çalışan küçük bir Kubernetes kümesi, bilgisayarına bir şey kurmuyorsun. Her komut yapıştırılabilir; bir saatlik oturum biterse hızlıca baştan başlayabilirsin.

**Çalışma kuralı:** *önce tahmin et, sonra çalıştır.* Her deneyden önce arkadaşına ne olacağını düşündüğünü söyle.

**Bugün Compose haritasına eklediklerimiz:** ayarlar ve sırlar (ConfigMap, Secret), `healthcheck` (probe'lar) ve `deploy.resources` (requests ve limits).

## Bölüm 0: Küme edin (5 dakika)

Geçen haftaki Killercoda Kubernetes playground'unu kullan (<https://killercoda.com/playgrounds>). Ücretsiz oturum yaklaşık bir saat sürer, sekmeyi kapatınca silinir. Diğer seçenekler: KodeKloud playground, iximiuz Labs, Kubernetes'i açılmış Docker Desktop veya `kind`.

```bash
kubectl get nodes
```

En az bir node'un `STATUS` değeri **Ready** olmalı. Aşağıdaki manifestler `cat <<'EOF'` ile yazılmış: bloğun tamamını yapıştırınca dosya oluşur. Emin değilsen `ls` ile dosyayı kontrol et.

## Bölüm 1: ConfigMap, ayarlar imajın dışında (10 dakika)

ConfigMap, ayarları anahtar-değer çiftleri olarak tutar. Pod'un onu hem **ortam değişkeni** hem **dosya** olarak okuyabilir. İmaj değişmez, sadece ConfigMap değişir.

```bash
cat <<'EOF' > app-config.yaml
# ConfigMap + Deployment: the app reads its settings from outside the image.
# The same ConfigMap is used twice: as environment variables and as a file.
apiVersion: v1
kind: ConfigMap
metadata:
  name: web-config
data:
  GREETING: "Hello from the ConfigMap"
  LOG_LEVEL: "info"
  index.html: |
    <h1>Hello from the ConfigMap</h1>
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: cfgweb
spec:
  replicas: 1
  selector:
    matchLabels:
      app: cfgweb
  template:
    metadata:
      labels:
        app: cfgweb
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          env:
            - name: GREETING            # one key as one variable
              valueFrom:
                configMapKeyRef:
                  name: web-config
                  key: GREETING
            - name: LOG_LEVEL
              valueFrom:
                configMapKeyRef:
                  name: web-config
                  key: LOG_LEVEL
          volumeMounts:
            - name: site
              mountPath: /usr/share/nginx/html   # the page nginx serves
      volumes:
        - name: site
          configMap:
            name: web-config
            items:
              - key: index.html                  # only this key becomes a file
                path: index.html
EOF
```

```bash
kubectl apply -f app-config.yaml
kubectl get pods
```

`Running` olmasını bekle. Ayarları Pod'un içinden oku:

```bash
kubectl exec deploy/cfgweb -- printenv GREETING LOG_LEVEL
kubectl exec deploy/cfgweb -- cat /usr/share/nginx/html/index.html
```

- **Tahmin et:** şimdi ConfigMap'i değiştireceksin. Önce hangisi değişir, ortam değişkeni mi dosya mı?

```bash
kubectl patch configmap web-config --type merge -p '{"data":{"GREETING":"Hello again","index.html":"<h1>Hello again</h1>\n"}}'
kubectl exec deploy/cfgweb -- printenv GREETING
kubectl exec deploy/cfgweb -- cat /usr/share/nginx/html/index.html
```

Değişken hâlâ eski değerde. Dosyanın değişmesi yaklaşık bir dakika sürebilir. `cat` komutunu 15 saniyede bir tekrarla, "Hello again" görene kadar. Ortam değişkenleri **sadece container başlarken, bir kez** okunur. Yeni değeri almak için Pod'ları yeniden başlat:

```bash
kubectl rollout restart deployment/cfgweb
kubectl rollout status deployment/cfgweb
kubectl exec deploy/cfgweb -- printenv GREETING
```

**Düşün:** bir satır yapılandırmayı değiştirdin ve imajı yeniden build etmedin. Hafta 5 Compose projende bu nerede işe yarardı?

## Bölüm 2: Secret, parolalar imajın ve Git'in dışında (8 dakika)

Secret, ConfigMap'e benzer ama parolalar ve anahtarlar için tasarlanmıştır. Komutla oluşturuyoruz, böylece değer commit edebileceğin bir dosyada durmaz.

```bash
kubectl create secret generic db-secret --from-literal=password=demo-not-a-real-password
kubectl get secret db-secret -o yaml
```

`data:` kısmına bak. Parola düz yazı görünmüyor, ama biraz daha yakından bak:

```bash
kubectl get secret db-secret -o jsonpath='{.data.password}' | base64 -d; echo
```

- **Önemli:** değer sadece **base64 ile kodlanmış**. Bu bir kodlamadır, şifreleme değil. Secret'ı okuma yetkisi olan herkes çözebilir. Gerçek koruma, Secret'ları kimin okuyabileceğini sınırlamaktan (RBAC) ve kümenin depolamasının şifrelenmesinden gelir; bunu küme yöneticileri ayarlar.

Şimdi bir Pod'da kullan:

```bash
cat <<'EOF' > secret-pod.yaml
# A Pod that reads a Secret as an environment variable and as a file.
# Create the Secret first:
#   kubectl create secret generic db-secret --from-literal=password=demo-not-a-real-password
apiVersion: v1
kind: Pod
metadata:
  name: secretpod
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "echo password-from-env is $DB_PASSWORD; ls /etc/creds; sleep 3600"]
      env:
        - name: DB_PASSWORD
          valueFrom:
            secretKeyRef:
              name: db-secret
              key: password
      volumeMounts:
        - name: creds
          mountPath: /etc/creds
          readOnly: true
  volumes:
    - name: creds
      secret:
        secretName: db-secret
EOF
```

```bash
kubectl apply -f secret-pod.yaml
kubectl logs secretpod
```

Ortam değişkenindeki parolayı ve `/etc/creds` içindeki dosya listesini görürsün.

**Düşün:** Secret imajın içinde değil, Git'te de değil. Ne kazandık? Bu Pod'da `kubectl exec` çalıştırabilen biri için hâlâ neler açıkta?

## Bölüm 3: Probe'lar, Kubernetes bir uygulamanın sağlıklı olduğunu nasıl bilir (14 dakika)

İki soru: **bu Pod trafik alabilir mi?** (readiness probe) ve **bu container hâlâ yaşıyor mu?** (liveness probe).

```bash
cat <<'EOF' > probes.yaml
# Two copies of nginx behind a Service, with a readiness and a liveness probe.
# Readiness: "may this Pod receive traffic?"  -> asks for the home page every 5 s.
# Liveness:  "is the container alive?"        -> only checks that port 80 accepts connections.
apiVersion: apps/v1
kind: Deployment
metadata:
  name: probeweb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: probeweb
  template:
    metadata:
      labels:
        app: probeweb
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          readinessProbe:
            httpGet:
              path: /
              port: 80
            periodSeconds: 5
            failureThreshold: 2
          livenessProbe:
            tcpSocket:
              port: 80
            initialDelaySeconds: 5
            periodSeconds: 10
---
apiVersion: v1
kind: Service
metadata:
  name: probeweb
spec:
  selector:
    app: probeweb
  ports:
    - port: 80
      targetPort: 80
EOF
```

```bash
kubectl apply -f probes.yaml
kubectl get pods
kubectl get endpointslices -l kubernetes.io/service-name=probeweb
```

`ENDPOINTS` sütununda iki Pod IP adresi görünür. Service'ten trafik alan Pod'lar bunlardır.

### 3a: Readiness probe'u boz

Bir Pod seç ve içindeki ana sayfayı sil:

```bash
POD=$(kubectl get pods -l app=probeweb -o name | head -1)
echo $POD
kubectl exec $POD -- rm /usr/share/nginx/html/index.html
```

- **Tahmin et:** Kubernetes bu Pod'u yeniden başlatır mı? Trafik almaya devam eder mi?

Yaklaşık 15 saniye bekle, sonra bak:

```bash
kubectl get pods
kubectl get endpointslices -l kubernetes.io/service-name=probeweb
kubectl describe $POD | tail -n 8
```

Şunu görmelisin: o Pod için `READY 0/1`, `RESTARTS` hâlâ 0 ve `ENDPOINTS` içinde sadece **bir** IP adresi kalmış. Olaylarda: "Readiness probe failed". Pod yaşıyor, sadece trafik almıyor. Onar:

```bash
kubectl exec $POD -- sh -c 'echo ok > /usr/share/nginx/html/index.html'
kubectl get pods
kubectl get endpointslices -l kubernetes.io/service-name=probeweb
```

Birkaç saniye sonra yine `1/1` olur ve iki IP adresi görünür.

### 3b: Liveness probe bozulan container'ı yeniden başlatır

```bash
cat <<'EOF' > liveness-exec.yaml
# A container that is healthy for 30 seconds, then "breaks" (the file disappears).
# The liveness probe notices and Kubernetes restarts the container.
apiVersion: v1
kind: Pod
metadata:
  name: liveness-demo
spec:
  containers:
    - name: app
      image: busybox:1.37
      command: ["sh", "-c", "touch /tmp/healthy; sleep 30; rm -f /tmp/healthy; sleep 600"]
      livenessProbe:
        exec:
          command: ["cat", "/tmp/healthy"]
        initialDelaySeconds: 5
        periodSeconds: 5
        failureThreshold: 2
EOF
```

```bash
kubectl apply -f liveness-exec.yaml
kubectl get pod liveness-demo -w
```

Yaklaşık bir dakika izle. `RESTARTS` 1 olunca `Ctrl+C` bas. Sonra:

```bash
kubectl describe pod liveness-demo | tail -n 12
```

"Liveness probe failed" ve "will be restarted" görmelisin. Container her başlangıçtan 30 saniye sonra bozuluyor, bu yüzden tekrar eder.

**Düşün:** ısınması 2 dakika süren bir uygulamaya iki probe'dan hangisini verirdin? Liveness probe çok katı olursa ne ters gidebilir?

## Bölüm 4: Kaynaklar, requests ve limits (8 dakika)

`requests` = Pod'un ihtiyacı (scheduler node seçerken bunu kullanır). `limits` = kullanabileceği en fazla miktar.

### 4a: Limiti aşan bellek

```bash
cat <<'EOF' > memhog.yaml
# A container that tries to use 250 MB but is only allowed 100 MiB.
# Memory over the limit -> the container is killed (OOMKilled).
# Note: polinux/stress is the image used in the official Kubernetes memory tutorial.
# It is a demo-only image, so we do not pin a tag here.
apiVersion: v1
kind: Pod
metadata:
  name: memhog
spec:
  containers:
    - name: stress
      image: polinux/stress
      command: ["stress"]
      args: ["--vm", "1", "--vm-bytes", "250M", "--vm-hang", "1"]
      resources:
        requests:
          memory: "50Mi"
        limits:
          memory: "100Mi"
EOF
```

```bash
kubectl apply -f memhog.yaml
kubectl get pod memhog -w
```

İlk çalıştırmada imaj iner, bekle. `OOMKilled` veya `CrashLoopBackOff` görünce `Ctrl+C` bas. Sonra:

```bash
kubectl get pod memhog -o jsonpath='{.status.containerStatuses[0].lastState.terminated.reason}'; echo
```

`OOMKilled`, container'ın limitinden fazla bellek kullandığı ve öldürüldüğü anlamına gelir. (CPU farklıdır: CPU limitini aşan container yavaşlatılır, öldürülmez.)

### 4b: Hiçbir node'un karşılayamadığı istek

```bash
cat <<'EOF' > toobig.yaml
# A Pod that asks for far more CPU than any node has.
# The scheduler cannot place it, so it stays Pending.
apiVersion: v1
kind: Pod
metadata:
  name: toobig
spec:
  containers:
    - name: app
      image: nginx:1.27
      resources:
        requests:
          cpu: "100"
          memory: "64Mi"
EOF
```

```bash
kubectl apply -f toobig.yaml
kubectl get pod toobig
kubectl describe pod toobig | tail -n 6
```

Pod `Pending` kalır. Olay, scheduler'ın yeterli CPU'su olan bir node bulamadığını söyler ("Insufficient cpu").

### 4c: İyi alışkanlık

```bash
cat <<'EOF' > resources-deployment.yaml
# The "good habit": every container declares what it needs (requests) and what it may use (limits).
apiVersion: apps/v1
kind: Deployment
metadata:
  name: sizedweb
spec:
  replicas: 2
  selector:
    matchLabels:
      app: sizedweb
  template:
    metadata:
      labels:
        app: sizedweb
    spec:
      containers:
        - name: nginx
          image: nginx:1.27
          ports:
            - containerPort: 80
          resources:
            requests:
              cpu: "50m"
              memory: "32Mi"
            limits:
              cpu: "200m"
              memory: "64Mi"
EOF
```

```bash
kubectl apply -f resources-deployment.yaml
kubectl get pod -l app=sizedweb -o jsonpath='{.items[0].status.qosClass}'; echo
```

`Burstable` yazar (requests, limits'ten küçük). Requests ve limits eşitse sınıf `Guaranteed` olur. Hiçbiri yoksa `BestEffort` olur; bir node'da bellek azalınca ilk atılan tür budur.

## Bölüm 5: Temizlik

```bash
kubectl delete deployment cfgweb probeweb sizedweb
kubectl delete service probeweb
kubectl delete configmap web-config
kubectl delete secret db-secret
kubectl delete pod secretpod liveness-demo memhog toobig
```

Killercoda sekmesini kapatmak zaten her şeyi siler.

## Compose'tan Kubernetes'e harita, bugünkü parçalarla

| Compose'ta | Kubernetes'te | Bugün |
|---|---|---|
| `environment:` | ConfigMap (env veya dosya) | Bölüm 1 |
| `.env`, secrets | Secret | Bölüm 2 |
| `healthcheck:` | readiness / liveness probe | Bölüm 3 |
| `deploy.resources` | `resources` (requests, limits) | Bölüm 4 |
| named volume | PersistentVolumeClaim | sadece slaytlarda |

## Komut özeti

```bash
kubectl apply -f DOSYA                        # dosyadan oluştur veya güncelle
kubectl exec POD -- KOMUT                     # Pod'un içinde komut çalıştır
kubectl get pods -w                           # Pod değişimlerini izle (Ctrl+C ile çık)
kubectl describe pod POD                      # ayrıntılar ve olaylar (alttan oku!)
kubectl create configmap AD --from-literal=ANAHTAR=DEGER
kubectl create secret generic AD --from-literal=ANAHTAR=DEGER
kubectl rollout restart deployment/AD         # Pod'ları tek tek yenile
kubectl get endpointslices -l kubernetes.io/service-name=AD
```

## Bir şey ters giderse

- **`polinux/stress` veya `busybox` için `ImagePullBackOff`:** bir dakika bekle ve `kubectl get pods` komutunu tekrar çalıştır; geçmezse `kubectl describe pod AD` içindeki Events kısmını oku ve bize söyle.
- **Bir dakika sonra dosya değişmedi:** doğru ConfigMap'i patch'lediğini kontrol et (`kubectl get configmap web-config -o yaml`) ve bir dakika daha bekle.
- **`AlreadyExists`:** komutu iki kere çalıştırdın. Sorun değil.
- **Oturum bitti:** yeni bir Killercoda oturumu aç ve blokları yeniden yapıştır.

## Düşünme soruları (her biri 2-3 cümle, kendi cümlelerinle yaz)

1. Ayarları imajın içinde değil de ConfigMap'te tutmak neden daha iyi? Neyin kolaylaştığını söyle.
2. Secret sadece base64 ile kodlanır. Yine de parolayı Deployment dosyasına yazmaktan neden daha iyidir?
3. Bir readiness probe başarısız oldu ama Pod yeniden başlatılmadı. Bu neden doğru davranış?
4. Limitinden fazla bellek kullanan container'a ne olur? Limitinden fazla CPU kullanırsa ne olur?
5. Bugünkü dört parçadan (ConfigMap, Secret, probe'lar, resources) hangisi kendi projene ilk olarak lazım olacak, neden?
