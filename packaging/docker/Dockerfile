FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive

WORKDIR /src

RUN apt-get update \
    && apt-get install -y --no-install-recommends \
        build-essential \
        bash \
        coreutils \
        findutils \
        iproute2 \
        procps \
        xdg-utils \
        zenity \
    && rm -rf /var/lib/apt/lists/*

COPY . .

RUN make clean && make test

CMD ["bash", "-lc", "printf 'FCFS\\n3\\n5,3,2\\n0,1,2\\n\\n1\\n' > /tmp/sched.in && ./sched_sim --input /tmp/sched.in --output /tmp/sched.out && cat /tmp/sched.out"]
