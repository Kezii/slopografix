 sudo docker build -t lol . ; sudo docker run --rm -it \
                                                          --device=/dev/ttyUSB0 \
                                                          --name minitel \
                                                          --hostname slopografix lol
