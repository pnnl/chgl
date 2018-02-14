FROM chapel/chapel-gasnet:1.16.0

RUN cd /opt/chapel/1.16.0 && make test-venv