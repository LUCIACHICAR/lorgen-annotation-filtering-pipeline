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
| `chr1:12738` | `CAGTG`→`C` | Real, extraído de gnomAD (`FILTER=PASS`, `AF=6.04522e-05`) | Indel real: prueba el arreglo de left-alignment (`-f`) y que, tras normalizar, sigue encontrando match en gnomAD |

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

## Resultado esperado al final del pipeline (`_final.vcf.gz`, sin filtro de genes)

- `chr1:12573 T>C` → AF real 0.000476644 (muy por debajo de 0.05) → **debe sobrevivir**.
- `chr1:12580 G>A` y `G>T` → sin dato en gnomAD → **deben sobrevivir** (gracias al cambio en `FILTER_AF`; antes de ese cambio se habrían descartado).
- `chr1:12738 CAGTG>C` → AF real 6.04522e-05 (muy raro) → **debe sobrevivir**.

Con estos tres registros, las cuatro variantes resultantes tras la
normalización deberían sobrevivir todas al filtro — si alguna desaparece,
es señal de que algo no está funcionando como se espera.

## Comparación antes/después (rama `main` vs `fix/indel-left-alignment`)

Este mismo fichero sirve para el plan de "correr dos veces y comparar":
- En `main` (código actual, sin `-f` en norm ni el cambio de `FILTER_AF`):
  `chr1:12580` (ambas líneas, sin dato) se **descartaría**. El indel
  `chr1:12738`, si no venía ya left-aligned, podría no encontrar match y
  también descartarse.
- En `fix/indel-left-alignment`: las cuatro variantes deberían sobrevivir.
