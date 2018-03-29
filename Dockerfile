FROM chapel/chapel-gasnet:1.16.0

RUN cd /opt/chapel/1.16.0 && make test-venv
RUN echo cibuild:x:1000:1000:cibuild:/home/users/cibuild:/bin/bash >> /etc/passwd
RUN sed -i '928s/pass/return/' /opt/chapel/1.16.0/util/start_test