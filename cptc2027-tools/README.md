# Tooling

# 2027

* asciinema
  * add time to a line 
    * add this in `.bashrc`: ```PS1='\[\033[01;32m\][\@] \u@\h:\w\$ \[\033[00m\]'```
  * record a session
    * ```asciinema rec file.cast```
      * end with ctrl+d or `exit`
  * replay a session
    * ```asciinema play file.cast```
      * pause with space
      * end with ctrl+c
    * ```asciinema upload file.cast```
      * sends recording to asciinema.org and gives a secret link to it
      * recordings without an account are deleted after 7 days
    * docker server
      * ```docker compose up``` on `cptc2026-tools/asciinemad/docker-compose.yml`
    * nix server
      * ```nix develop``` on `asciinema/flake.nix`
      * runs the .cast files on a web server
      * ```castserve file1.cast file2.cast```
