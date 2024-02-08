FROM perl:latest

RUN cpanm Feersum
RUN cpanm Plack
RUN cpanm Plack::Middleware::CrossOrigin
RUN cpanm JSON::WebToken
RUN cpanm LWP::UserAgent -force
RUN cpanm Path::Tiny
RUN cpanm Data::UUID

WORKDIR /usr/src/app

COPY . .

EXPOSE 3000

CMD ["feersum", "--listen", ":3000"]

#CMD ["tail", "-f", "/dev/null"]
