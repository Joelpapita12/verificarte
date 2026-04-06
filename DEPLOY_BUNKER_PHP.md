# Despliegue PHP 8.2 + MariaDB para Bunker Verificarte

Esta version ya no usa Node.js para produccion. El puente unico es:

- `api_master.php`

## 1. Archivos que vas a subir por FileZilla

### Frontend

Sube el contenido de:

- `C:\Flutter\verificarte_web\verificarteweb\build\web`

hacia:

- `/public_html/`

### Puente PHP

Sube estos archivos de:

- `C:\Flutter\verificarte_web\verificarteweb\php_bridge`

hacia:

- `/public_html/`

Archivos:

- `api_master.php`
- `env_loader.php`
- `.htaccess`
- `.env` (este sale de renombrar `.env.example`)

## 2. Como debe llamarse el archivo de entorno del puente

Local:

- `php_bridge/.env.example`

En el servidor:

- `/public_html/.env`

## 3. Contenido del `.env` del puente PHP

```env
DB_HOST=db5020077295.hosting-data.io
DB_PORT=3306
DB_NAME=dbs15474121
DB_USER=dbu3449997
DB_PASS=Ch4ng0#26$J03l
BUNKER_API_KEY=T4t3W4r1_S3cr3t_2026_X
```

## 4. Respaldo SQL con datos

Usa este archivo para importar toda la base con informacion:

- `C:\Flutter\verificarte_web\verificarteweb\backups\verificarte_2026-03-24.sql`

Si quieres solo la estructura:

- `C:\Flutter\verificarte_web\verificarteweb\backups\verificarte_schema_2026-03-24.sql`

## 5. Importar base

Desde phpMyAdmin:

1. entra a la base `dbs15474121`
2. usa `Importar`
3. selecciona `verificarte_2026-03-24.sql`

## 6. Frontend apuntando al puente

El archivo clave del frontend es:

- `lib/services/bunker_db.dart`

La URL ya debe quedar asi:

- `https://verificarte.softapatio.mx/api_master.php`

## 7. Nota importante

En este punto el puente PHP ya queda listo para hablar con MariaDB.

Lo que sigue naturalmente es migrar las pantallas/servicios del frontend para usar
`BunkerDB.consulta(...)` en lugar de los endpoints REST viejos.
