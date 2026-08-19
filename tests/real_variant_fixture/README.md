# Fixture: variantes reales para probar norm + annotate + filter juntos

A diferencia de `tests/leftalign_fixture/` (secuencia inventada, solo para probar
el mecanismo de left-alignment en aislado), este fichero usa **coordenadas
genómicas reales** (GRCh37/hg19) para poder probar la cadena completa
`NORMALIZE_VCF → ANNOTATE_VCF → FILTER_AF` de una sola vez, con datos
pequeños y rápidos de ejecutar.

## ⚠️ Antes de usarlo: dos campos marcados como "VERIFY_REF"

Dos de los cuatro registros tienen `VERIFY_REF` en el campo `ID` porque no he
podido confirmar la secuencia exacta de referencia alrededor de esa posición
sin el FASTA real (no tengo acceso a consultarlo desde aquí). **No pasa nada
si están mal** — en cuanto se ejecute `NORMALIZE_VCF` con `-c e`, si el `REF`
no coincide con el genoma real, el pipeline **parará con un error explícito**
en vez de dar un resultado silenciosamente incorrecto. Si eso ocurre:

```bash
samtools faidx referencia.fasta chr7:117199640-117199650
samtools faidx referencia.fasta chr19:45411985-45411995
```
y ajusta el `REF` de ese registro para que coincida exactamente con lo que
devuelva `samtools faidx` en esa posición.

## Los cuatro registros

| # | Posición (GRCh37) | Qué es | Qué prueba |
|---|---|---|---|
| 1 | `chr19:45412079` C→T,G | rs7412 (APOE) real, con un segundo alelo `G` añadido a propósito (no verificado en gnomAD) | `bcftools norm -m -any` debe partirlo en dos líneas biálelicas (`C>T` y `C>G`) |
| 2 | `chr19:45411941` T→C | rs429358 (APOE), variante real y muy conocida | SNP simple: debe pasar por `NORMALIZE_VCF` sin cambios, y `ANNOTATE_VCF` debería encontrarla en gnomAD (tendrá un `gnomAD_AF` real) |
| 3 | `chr7:117199644` ATCT→A | rs113993960, deleción ΔF508 de *CFTR* (la causa más común de fibrosis quística) | Indel real conocido: debería, tras el arreglo de `-f`, quedar left-aligned correctamente y encontrar match en gnomAD (`gnomAD_AF` con valor real) |
| 4 | `chr19:45411990` G→A | Inventada a propósito, cerca de las otras dos pero sin motivo para estar catalogada | Comprueba que `FILTER_AF` **conserva** las variantes sin dato de gnomAD (`gnomAD_AF="."`), en vez de descartarlas — el cambio que acabas de hacer |

## Cómo prepararlo para el pipeline

El pipeline espera `.vcf.gz` + índice. Sitúalo como si fuera una muestra de
`VCF_NEXT/` o `VCF_CEGAT/` (no necesita fusión, es un único fichero):

```bash
cd tests/real_variant_fixture
bgzip -c sample_test.vcf > sample_test.vcf.gz
tabix -p vcf sample_test.vcf.gz

# Copialo a una carpeta de entrada de prueba, ej.:
mkdir -p /tmp/test_vcf_input/VCF_NEXT
cp sample_test.vcf.gz /tmp/test_vcf_input/VCF_NEXT/
```

## Resultado esperado al final del pipeline (`_final.vcf.gz`, sin filtro de genes)

- Registro 1a (`chr19:45412079 C>T`) y 1b (`chr19:45412079 C>G`): el `T` es rs7412 real, probablemente con AF bajo → debería sobrevivir. El `G` casi seguro no está en gnomAD → debería sobrevivir también gracias al cambio de "conservar sin dato".
- Registro 2 (rs429358): variante común, con AF real de gnomAD — comprueba en el resultado si su AF es mayor o menor de 0.05 para saber si debería sobrevivir o no (es una variante relativamente frecuente en población, puede que se descarte por ser común — eso también sería correcto).
- Registro 3 (CFTR ΔF508): variante rara a nivel poblacional general — se espera que sobreviva.
- Registro 4 (inventada): sin dato en gnomAD — debería sobrevivir (si no sobrevive, revisa que el cambio en `FILTER_AF` se aplicó bien).

Como con el registro 2 no sabemos de antemano si su AF real es mayor o menor
de 0.05, ese es el único resultado "abierto" — mira el valor real de
`gnomAD_AF` en el `_annotated.vcf.gz` para interpretarlo correctamente en
vez de asumir un resultado.
