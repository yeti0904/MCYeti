# BlockDB
The BlockDB is in a custom binary file format

It is made up of 48 byte large entries only

## Data types
- String: same as classic protocol strings, but 16 characters long
- Word: 16-bit unsigned integer, big endian order
- QWord: 64-bit unsigned integer, big endian order

## Entries
| Field name  | Offset | Size (Bytes) | Data type | Info                    |
| ----------- | ------ | ------------ | --------- | ----------------------- |
| Player name | 0x00   | 0x10         | String    | Username                |
| X           | 0x10   | 0x02         | Word      | X block coordinate      |
| Y           | 0x12   | 0x02         | Word      | Y block coordinate      |
| Z           | 0x14   | 0x02         | Word      | Z block coordinate      |
| Block type  | 0x16   | 0x02         | Word      | Block ID                |
| Time        | 0x18   | 0x08         | QWord     | Stores as a unix time   |
| Extra       | 0x20   | 0x10         | String    | Info about modification |
