# Fixture: variantes reales para probar norm + annotate + filter juntos

A diferencia de `tests/leftalign_fixture/` (secuencia inventada, solo para probar
el mecanismo de left-alignment en aislado), este fichero usa **datos extraídos
directamente del gnomAD y del genoma de referencia reales del servidor**
(`/mnt/data/exome/gnomad.withchr.bgz.vcf.gz` y `/mnt/data/hg19_ref_genome/genome.fa`,
GRCh37) — no hay ninguna coordenada inventada ni sin verificar. Permite probar
la cadena completa `NORMALIZE_VCF → ANNOTATE_VCF → FILTER_AF` con datos
pequeños, reales y rápidos de ejecutar.

## Los tres registros (todos verificados contra los ficheros reales del servidor)

| Posición (GRCh37) | REF→ALT | Origen | Qué prueba |
|---|---|---|---|
| `chr1:12573` | `T`→`C` | Real, extraído de gnomAD (`FILTER=PASS`, `AF=0.000476644`) | SNP simple: debe pasar sin cambios por `NORMALIZE_VCF` y anotarse con su `gnomAD_AF` real en `ANNOTATE_VCF` |
| `chr1:12580` | `G`→`A,T` | `REF` real (confirmado con `samtools faidx` sobre el genoma real); ambos `ALT` inventados. Posición confirmada **ausente** de gnomAD (`bcftools view` no devuelve nada ahí) | `bcftools norm -m -any` debe partirlo en dos líneas (`G>A` y `G>T`); ninguna de las dos debería encontrar match en gnomAD → prueba que `FILTER_AF` **conserva** lo que no tiene dato (el cambio que hiciste), y de paso prueba la división de multialélicos |
| `chr1:12742` | `GAGTG`→`G` | El mismo indel real de gnomAD (`FILTER=PASS`, `AF=6.04522e-05`, canónico en `chr1:12738 CAGTG>C`), pero **anclado a propósito en la copia derecha** de la repetición en tándem `AGTG`/`AGTG` (`chr1:12739-12746`) en vez de la izquierda — un desplazamiento real y válido, no un error de datos | Indel real, deliberadamente no-canónico: solo debería encontrar match en gnomAD **si** `NORMALIZE_VCF` lo realinea de vuelta a `chr1:12738`. Prueba el arreglo de left-alignment (`-f`) de verdad, no solo que un indel ya-canónico siga matcheando |

No hace falta un cuarto registro para "SNP único" aparte — cuando `chr1:12580`
se divida, cualquiera de sus dos líneas resultantes ya es, de cara al resto
del pipeline, un SNP simple normal; y `chr1:12573` ya cubre el caso de SNP
real anotado con gnomAD.

## Cómo prepararlo para el pipeline

```bash
cd tests/real_variant_fixture
bgzip -c sample_test.vcf > sample_test.vcf.gz
tabix -p vcf sample_test.vcf.gz

mkdir -p /tmp/test_vcf_input/VCF_NEXT
cp sample_test.vcf.gz /tmp/test_vcf_input/VCF_NEXT/
```

## Resultado esperado — comparación antes/después (rama `main` vs `fix/indel-left-alignment`)

| Variante | En `main` (código actual) | En `fix/indel-left-alignment` |
|---|---|---|
| `chr1:12573 T>C` | Sobrevive (`gnomAD_AF=0.000476644`) | Igual, sin cambios — sirve de control |
| `chr1:12580 G>A` / `G>T` | **Se descartan** (sin dato en gnomAD, `FILTER_AF` antiguo las excluye) | **Sobreviven** (el cambio en `FILTER_AF` las conserva) |
| `chr1:12742 GAGTG>G` (indel desplazado) | **No encuentra match** (queda en `POS=12742`, gnomAD lo tiene en `12738`) → se descarta | `NORMALIZE_VCF` lo realinea a `chr1:12738 CAGTG>C` → **sí encuentra match** (`gnomAD_AF=6.04522e-05`) → sobrevive |

Ya confirmamos el "antes" con la versión anterior de este fichero (cuando el
indel todavía estaba en su posición canónica `12738`) — con el indel ya
desplazado a `12742`, **hay que repetir la pasada de `main`** para tener el
"antes" correcto de este caso concreto: ahora se espera que en `main`
sobrevivan **solo 1** de las 4 variantes resultantes (`chr1:12573`), y que en
la rama con el arreglo sobrevivan las **4**.
