# py-run

Докер контейнер, после старта запускающий Python скрипт.

## Использование

Сохраните свой скрипт в папку с контейнером и укажите его имя в переменной **PY_SCRIPT**, после чего запустите контейнер.

### Docker Compose

```yaml
# docker-compose.yml
services:
  py-run:
    container_name: py-run
    image: ghcr.io/codinv/py-run
    network_mode: bridge
    volumes:
      - ./:/app
    environment:
      - TZ=Europe/Moscow
      - PY_SCRIPT=./myscript.py   # <-- замените на имя своего скрипта
    restart: unless-stopped
```

### Docker Run

```bash
docker run -d \
  --name py-run \
  --network bridge \
  -v "$(pwd)":/app \
  -e TZ=Europe/Moscow \
  -e PY_SCRIPT=./myscript.py \
  --restart unless-stopped \
  ghcr.io/codinv/py-run
```

## Переменные

| Переменная | Описание | По умолчанию |
|------------|----------|--------------|
| `PY_SCRIPT` | Имя Python скрипта | `./myscript.py` |
| `TZ` | Часовой пояс | `Europe/Moscow` |
