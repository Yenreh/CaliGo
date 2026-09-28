# Services CaliGo reads

Every piece of transit data comes from public services of Metro Cali S.A.
([metrocali.gov.co](https://www.metrocali.gov.co)), which allows reusing
its information for informative, non-commercial ends citing the source.
None of them needs a key. They are not documented by their owner and may
change without notice.

## Balance

```
GET https://metrocali.gov.co/cts/api/cts.php?numero={13 digits}
```

Success (HTTP 200):

```json
{"cardNumber":1906051868981,"cd_id":6,"crd_snr":5186898,
 "tsn":525,"balance":15300.0,"balanceDate":1785631011000}
```

`balanceDate` is epoch milliseconds. A card without movements comes back
with `cardNumber` 0. Failures also answer HTTP 200, as
`{"error": "..."}` with a generic message, so the app checks the 13 digits
itself before asking.

## Arrivals

```
GET https://servicios.siur.com.co/buscarutas/api/paradas_con_buses_proximos_a_llegar.php
    ?latitud={lat}&longitud={lon}&radio={metres, 300 at most}
```

An array of stops, each with the buses on their way:

```json
[{"idParada":"500800","nombreParada":"Plaza de Cayzedo A1",
  "distanciaMetros":119.52,
  "buses":[{"nombreLinea":"E21","nombreDestino":"Est. Universidades",
            "tiempoEstimadoDeSalida":1787429222000,"vehiculoId":"637001"}]}]
```

`tiempoEstimadoDeSalida` is epoch milliseconds. Stops with no bus coming
are left out. The service takes coordinates only and does not say where
each stop is, so the app queries the same area from two nearby points and
places each stop from the three distances.

## Catalog, lines and buses

Base: `https://wsmio.siur.com.co:8083/apiMIO/jaxrs`

| Resource | Returns | Cached |
| --- | --- | --- |
| `stations` | every station: id, name, address, lat/lon | 7 days |
| `linesByStop/{stop}` | lines serving a stop | 30 days |
| `lines` | every line: `lineId`, `name` | 7 days |
| `linestops/{line}` | a line's route, by short name (`A47`): stops in order per direction (`orientation` 0/1, `stopSequence`, `stopId`, `stopNam`, lat/lon) | 7 days |
| `linesOperation` | each line's first and last service, `HH:mm:ss` | 1 day |
| `operations/{line}` | buses running now: `busNumber`, `gpsx`/`gpsy` as degrees times 10^7 | never |
| `busInfo/{bus}` | the bus's trip, including its direction (`orientation`) | 10 minutes |

## Being a good client

- A service that answers HTTP 429, or keeps failing after one retry, is
  left alone for 1, 2, 4, 8 and at most 16 minutes; the first normal
  answer clears the wait. Rate limits are never retried.
- Arrivals refresh every 30 s while a bus is within 5 minutes, every 60 s
  within 15, otherwise every 120 s, and never in the background.
- Nearby favorites share one request, identical requests in flight share
  one answer, and what barely changes is cached as above.
