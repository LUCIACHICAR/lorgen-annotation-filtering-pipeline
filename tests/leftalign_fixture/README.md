# Fixture: verificación de left-alignment de indels

Prueba mínima y determinista para confirmar que `bcftools norm -f` deja los indels
en su posición canónica (más a la izquierda), antes de aplicar el cambio al
pipeline real. No usa datos de pacientes ni el genoma completo — es un
fragmento inventado de 20 bases, pensado solo para este test.

## La referencia (`tiny_ref.fasta`)

```
Posición: 1  2  3  4  5  6  7  8  9  10 11 12 13 14 15 16 17 18 19 20
Base:     C  G  T  C  A  A  A  A  A  T  G  C  A  T  G  C  A  T  G  C
```

Hay una repetición de 5 "A" en las posiciones 5-9 — el tipo de zona donde un
indel puede escribirse en varias posiciones distintas que significan
biológicamente lo mismo (justo el problema que estamos corrigiendo).

## La variante de prueba (`test_not_aligned.vcf`)

Representa "se ha borrado una A de la repetición" (de AAAAA a AAAA), pero
colocada **a propósito en la posición NO canónica** (la más a la derecha
posible), para comprobar que `bcftools norm -f` la mueve a la izquierda:

```
chr_test  8  .  AA  A
```
(en la posición 8: "AA" → "A", es decir, borra la A de la posición 9)

## Resultado esperado tras `bcftools norm -f`

La misma variante, pero en su posición canónica más a la izquierda (posición 4,
justo donde empieza la repetición):

```
chr_test  4  .  CA  C
```
(en la posición 4: "CA" → "C", es decir, borra la primera A de la repetición)

Ambas representan exactamente el mismo cambio genético — la prueba es que
`bcftools norm -f` las trate como equivalentes y normalice siempre a la
segunda forma.

## Cómo ejecutarlo

**Paso 1 — comprobar el comando de bcftools de forma aislada** (sin Nextflow,
para confirmar el mecanismo antes de tocar el pipeline):

```bash
cd tests/leftalign_fixture
samtools faidx tiny_ref.fasta
bcftools norm -f tiny_ref.fasta test_not_aligned.vcf -Ov
```

**Resultado esperado** (entre las líneas de cabecera `##...`):
```
chr_test	4	.	CA	C	50	PASS	.
```

Si sale `POS=4, REF=CA, ALT=C` → el mecanismo funciona como esperamos.
Si sale `POS=8` sin cambios (o cualquier otra cosa) → algo no encaja y hay
que revisar antes de aplicarlo al pipeline real.

**Paso 2 — una vez confirmado el paso 1**, se integrará en
`modules/local/normalize_vcf.nf` (rama `fix/indel-left-alignment`) y se
volverá a lanzar este mismo fichero a través del proceso real de Nextflow,
para confirmar que también funciona dentro del pipeline.

**Paso 3** — solo al final, probar con los datos reales de NOVOGENE ya
existentes en `data/vcf_input/`, para confirmar que no rompe nada a escala
real (no para demostrar que funciona — eso ya lo habrá demostrado el paso 1).
