"""
Applet: Plex Tracks
Summary: Display info on currently playing music from Plex server
Description: Configure with IP/Domain of a plex server, the API key, and it'll show the currently playing track and artwork
Author: poprhythm
"""

load("render.star", "render")
load("schema.star", "schema")
load("encoding/base64.star", "base64")
load("http.star", "http")
load("xpath.star", "xpath")
load("random.star", "random")
load("cache.star", "cache")

DEFAULT_ADDR = ""
DEFAULT_PORT = "32400"
DEFAULT_PLEXTOKEN = ""
DEFAULT_PLAYER = ""
CACHE_TTL = 45

def main(config):
    addr = config.get("addr", DEFAULT_ADDR)
    port = config.get("port", DEFAULT_PORT)
    token = config.get("token", DEFAULT_PLEXTOKEN)
    player = config.get("player", None)

    trackInfo = update_plex_status(addr, port, token, player)

    if trackInfo == None:
        print("Plex is silent")
        quote = SILENCE_QUOTES[random.number(0,len(SILENCE_QUOTES))]
        return render.Root(
            render.Column([
                render.Image(src=PLEX_LOGO_W48),
                render.Marquee(render.Text(quote, font="tom-thumb"), width=64)
                ],
            expanded=True,
            main_align="center",
            cross_align="center"
            )
        )

    if "status_code" in trackInfo:
        return render.Root (
                render.Column ([
                    render.Text("Plex request failed:"),
                    render.Marquee(
                        render.Text(trackInfo["status_code"]),
                        width = 64,
                    )]
            )
        )
    
    return render.Root(
        child = render.Box(
            render.Row([
                    render.Image(src=trackInfo["thumbnail"], width = 32, height = 32),
                    render.Column([
                            render.Image(src=PLEX_LOGO_H8),
                            render.Marquee(
                                render.Text(trackInfo["title"]),
                                width = 32,
                            ),
                            render.Marquee(
                                render.Text(trackInfo["artist"]),
                                width = 32,
                            ),
                            render.Marquee(
                                render.Text(trackInfo["album"]),
                                width = 32,
                            )
                        ]
                    )
                ],
            ),
        ),
    )

def update_plex_status(addr, port, token, player):

    if cache.get("title") != None:
        return {
            "title": cache.get("title"),
            "artist": cache.get("artist"),
            "album": cache.get("album"),
            "thumbnail": base64.decode(cache.get("thumbnail"))
        }

    status_url = "http://%s:%s/status/sessions?X-Plex-Token=%s" % (addr,port,token)

    rep = http.get(status_url)

    if rep.status_code != 200:
        print("Plex request failed with status %d", rep.status_code)
        return {"status_code": rep.status_code}

    xml = rep.body()
    xp = xpath.loads(xml)

    query = "//Track"
    if not(player == None or not player):
        query += "[contains(Player/@title,'%s')]" % player
    
    t = xp.query_node(query)

    if t == None:
        return None

    title = t.query("@title")

    artist = t.query("@originalTitle")
    if artist == None:
        artist = t.query("@grandparentTitle")
        album = t.query("@parentTitle")
    else:
        album = t.query("@parentTitle")

    #print("%s - %s" % (artist, title))

    thumbnail_path = t.query("@thumb")
    thumbnail_url = "http://%s:%s%s?X-Plex-Token=%s" % (addr,port,thumbnail_path,token)
    thumbnail_rep = http.get(thumbnail_url)

    trackInfo = {
        "title": title,
        "artist": artist,
        "album": album,
        "thumbnail": thumbnail_rep.body()
    }

    cache.set("title", trackInfo["title"], CACHE_TTL)
    cache.set("artist", trackInfo["artist"], CACHE_TTL)
    cache.set("album", trackInfo["album"], CACHE_TTL)
    cache.set("thumbnail", base64.encode(trackInfo["thumbnail"]), CACHE_TTL)

    return trackInfo

def get_schema():
    return schema.Schema(
        version = "1",
        fields = [
            schema.Text(
                id = "addr",
                name = "IP/Domain",
                desc = "IP or Domain of Plex Server",
                icon = "location-dot",
                default = DEFAULT_ADDR,
            ),
            schema.Text(
                id = "port",
                name = "Port Number",
                desc = "Port on which Plex Server is hosted",
                icon = "location-dot",
                default = DEFAULT_PORT,
            ),
            schema.Text(
                id = "token",
                name = "X-Plex-Token",
                desc = "Token for Plex API commands",
                icon = "hashtag",
                default = DEFAULT_PLEXTOKEN,
            ),
            schema.Text(
                id = "player",
                name = "Player Name to Display",
                desc = "Leave blank for first match",
                icon = "mp3-player",
                default = DEFAULT_PLAYER,
            )
        ],
    )

PLEX_LOGO_H8 = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAACAAAAAICAYAAACYhf2vAAAAeElEQVQ4T2N
kIAH8BwKQckYgIEEbXqUoBiFbAGMjW4jNAcjqUNQe4oM41u4TTjvA8sjOI2
QpugMI8tEcgc0DeF0HcxxIIyjYcVmIHsbIUfQf6ghsoUH1EEB3CMxyWDQQH
QJ4fYSWEGmSBqiZygnlFow0QE/LQY4DALpxgAnhQU15AAAAAElFTkSuQmCC
""")

PLEX_LOGO_W48 = base64.decode("""
iVBORw0KGgoAAAANSUhEUgAAADAAAAAXCAYAAABNq8wJAAAACXBIWXMAAACIAAAA
iAHr3JJSAAADq0lEQVRYhd1XX0iTURS/i0XF0i0MFEYoKkj2Insq0LGnvURgsPDF
B5FeehjYXgrsUWtCmriH+aBiKFFusLk39cU2JoG5fDKFMRxM3Jhkm20LFn3xG99d
d9frPqdC2oHLvnPPuefPPeeec0YkSTrxGhsb65MYWFtb2z+NvJOsS+SCw//tgMPh
6BsZGek6K2WQBZlnJQ+gDoVC+xSJxWLb0Wj0rdlsftnS0nLNarVS0vtAIBBfXV3t
s9lsHypRAIPb2tqedXR01NlsNrr9ZmtrKxcMBt/19vY+3vOqGggh09zR9ZudUtHZ
wcHBeqPR+Emj0Vyle5lM5idhH2EqlfotKcDk5OQEfWxKj1jmLQt+v393YGCgPukh
3qSHSNzqpLLm5+e/8HJmZmY8REmBCIaHh7uUHDiO8RTgRNJDdEkP+c45AFzH62F1
Cd9AOp2WfD7fusvl+hgKhb7zdJPJNF4ubRBui8XSy+4hBR0Ox1MsyGZpSC/ft8nX
hJAeTpQWqZVOpz2wibVvaWnpQQHhPdvc3MwipEqpYLfb24+KAELL3zBf43mZ0Iv9
o1LJ6XS+oryy/IIcNX/zbrf7dn9/f5Tdx0NbXFw0mc3mpuLVaLX38/l8QhSB1tZW
E4vncrmMy+VaZveqqqoK+qqrq1XAUTRkEqKwLd8+hWlL3ZOGQOBODx5xd3f3Q0oo
cSAcDqd44ylEIhEXIeQ5xWtqau7F43GviLe2tvY6i8uON4l4WUDFslql0T2vCk54
GFIhlfx+/10gBoOhSDhXjSyfz+8q8ajV6lslOIs0Nzdr8QBFUWhsbHzE4gcHB2Ge
R6PRXMFvIpH4odfrdXR/fHzcflS6sYAes+dV6QQ9IYXUMhqNX+U+cIMSSiKAfESz
gBPs/tTU1ASb/4BkMskrKeTx0NBQ+8bGRkm+I92sVusou/iz2Wz2s/w5zeU/oMcd
dxaaocFg0M3Ozv5NL1FdjsVieTSOubm5ZbmyCGuwqD7jDKoY3xRRicCPaiKSCRqq
jaACeXl5+Ka96FSNTP4tAQiHwkoa2cLCQrjSRoZLhp5DDpQbJ0BjRwks0W1SnuM4
AePl+r9cbpRAZPmziOohB3CrIqOgCM1L9KcDhlLH5ZmlSMMZnOUvBjrk5gTj22QH
2DXK62HnITQ+2CpKoeIBhI6mi9Liu7dogec4fJXoUhUslmFnZ+eXXq+/rFTuzhOU
lNGVlZXgRTKesA5gDopEIi/+rTmVgxrjLT4wsh41B51bIIT8AdWtg7+vr6x4AAAA
AElFTkSuQmCC
""")

SILENCE_QUOTES = [
    "Listen to silence. It has so much to say. Rumi",
    "Silence is the sleep that nourishes wisdom. Francis Bacon",
    "Noise creates illusions. Silence brings truth. Maxime Lagacé",
    "Speech is silver, silence is golden. Thomas Carlyle",
    "Silence is a source of great strength. Lao Tzu",
    "Silence is sometimes the best answer. Dalai Lama",
    "Silence is a true friend who never betrays. Confucius",
    "The truth hurts, but silence kills. Mark Twain",
    "To hear, one must be silent. Ursula K. Le Guin",
    "Sound is our mind, silence is our being. Osho"
]
