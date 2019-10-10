FROM swift:4.2

WORKDIR /Wall-E
COPY . /Wall-E

RUN swift build -c release

EXPOSE 2008

CMD ./.build/release/Run --env production --hostname 0.0.0.0 --port 2008
