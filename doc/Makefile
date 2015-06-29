DOT = dot

all: svg pdf

pdf: $(patsubst %.dot,%.pdf,$(wildcard *.dot)) Makefile
svg: $(patsubst %.dot,%.svg,$(wildcard *.dot)) Makefile

clean:
	rm -f $(patsubst %.dot,%.pdf,$(wildcard *.dot))
	rm -f $(patsubst %.dot,%.svg,$(wildcard *.dot))
	#rm -f *.bak *~

%.pdf: %.dot
	$(DOT) -Tpdf -o $@ $<

%.svg: %.dot
	$(DOT) -Tsvg -o $@ $<

