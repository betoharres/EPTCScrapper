# Usage

1. install the gems required in the
scripts(`scrap.rb`, `models.rb`, `EPTCBus.rb`)

2. run: ``$ ruby scrap.rb``

It will output a `.db` file

**NOTES**:
- one url at a time otherwise EPTC's website will go down
- entire process take around 1h

## Bus example:

```
sqlite> select * from buses where id=1;
        id = 1
identifier = 256-44
      name = INTENDENTE AZEVEDO (BACIA PÚBLICA)
      code = 2564
       url = http://www.eptc.com.br/EPTC_Itinerarios/Cadastro.asp?Linha=256-44&Tipo=TH&Veiculo=1&Sentido=0&Logradouro=0&Action=Tabela
```

## Schedule example:

```
sqlite> select * from schedules where id=1;
           id = 1
    direction = 2
     day_type = 1
         time = 06:48
stop_datetime = 2020-01-01 06:48:00
  is_handicap = 1
```

## direction_types:

```
  unknown: 0         , circular: 1        ,
  bairro_centro: 2   , centro_bairro: 3   ,
  bairro_terminal: 2 , terminal_bairro: 5 ,
  norte_sul: 6       , sul_norte: 7       ,
  norte_leste: 8     , leste_norte: 9     ,
  leste_sul: 10      , sul_leste: 11      ,
```

## day_types:

```
 unknown: 0, mon_fri: 1, saturday: 2, sunday: 3
```

## bonus(how many bus schedules supports wheelchair):

```
sqlite> select count(*) from schedules where is_handicap=1;
count(*) = 16266
sqlite> select count(*) from schedules where is_handicap=0;
count(*) = 25310

```
