FROM "ruby"

RUN apt update
RUN apt install ffmpeg python3 -y
RUN wget "https://github.com/yt-dlp/yt-dlp/releases/latest/download/yt-dlp_linux"
RUN chmod a+x yt-dlp_linux
RUN mv yt-dlp_linux /usr/bin

RUN mkdir -p /opt/downloader
WORKDIR /opt/downloader

ADD . /opt/downloader
RUN bundle

CMD ["ruby", "main.rb"]
