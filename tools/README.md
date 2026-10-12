# Pipeline de modelos (tools)

Infraestructura reproducible para **traer, verificar y validar** modelos de
dinosaurio antes de integrarlos en el juego. **No modifica el juego.**

## Fuentes y licencia

Todos los modelos provienen de **Poly Pizza** (agregador), autor **Quaternius**,
licencia **Public Domain (CC0)**. Se registran URL de descarga y página de origen
en `tools/models_manifest.json`.

| Especie | Autor | Licencia | Estado |
|---|---|---|---|
| T-Rex | Quaternius | CC0 | descargado y validado |
| Velociraptor | Quaternius | CC0 | descargado y validado |
| Triceratops | Quaternius | CC0 | descargado y validado |

> No se descarga ningún recurso sin licencia CC0 declarada en `fetch_models.py`.

## Uso

```powershell
# 1) Descargar / actualizar y regenerar el manifiesto (registra sha256, bytes, urls)
python tools/fetch_models.py

# 2) Solo verificar (no descarga)
python tools/fetch_models.py --check

# 3) Validar en Godot headless (clips de animacion, huesos, tamano)
godot --headless --path . "res://tools/validate_models.tscn"
```

`validate_models` parsea los `.glb` en runtime con `GLTFDocument`, por lo que
**no depende del pipeline de import** de Godot (útil porque este entorno no
importa `.blend` en headless).

## Resultado de la validacion (2025)

```
trex.glb        clips=6 [Attack, Death, Idle, Jump, Run, Walk]  bones=29
velociraptor.glb clips=6 [Attack, Death, Idle, Jump, Run, Walk] bones=29
triceratops.glb  clips=6 [Attack, Death, Idle, Jump, Run, Walk] bones=29
```

Los nombres de clip incluyen el prefijo de armadura, p. ej.
`Armature|Triceratops_Run`. Por eso `DinoBase` resuelve animaciones por
**palabra clave** (idle/walk/run/jump), conservando como compatibilidad los
nombres fijos `Armature|TRex_*`.

## Limitaciones conocidas

- Importar `.blend` directamente en Godot **no funciona en headless** en este
  entorno (solo editor GUI). Usar `.glb`.
- La validacion reporta el AABB del mesh en su espacio local; la escala/origen
  finales se ajustan por especie al integrar.
- No genera geometria nueva: reutiliza modelos CC0 existentes.
