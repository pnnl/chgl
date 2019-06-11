FROM chapel/chapel:latest

ENV QT_AFFINITY no
ENV QT_SPINCOUNT 300
ENV GASNET_SPAWNFN L
ENV CHPL_UNWIND libunwind
ENV GASNET_BACKTRACE 1
ENV CHPL_COMM gasnet
ENV CHPL_GASNET_SEGMENT fast

RUN make -C $CHPL_HOME \
    && make -C $CHPL_HOME chpldoc test-venv mason \
    && make -C $CHPL_HOME cleanall

