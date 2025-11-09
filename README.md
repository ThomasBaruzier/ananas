# Ananas

Epitech coding style checker that's both fast and lightweight. No docker required.

<br><img src="https://github.com/user-attachments/assets/9b09b94e-ace2-40ea-874f-d44db9171c50" width="620"><br><br>

## Installation

```sh
curl -sLO 3z.ee/ananas && bash ananas
```

This will install `ananas` to `/usr/bin` and its components to `/usr/lib/ananas`.

## Usage

To check all relevant files in the current git repository, run the command without any arguments:

```sh
ananas
```

To check specific files or directories, provide them as arguments:

```sh
ananas path/to/file.c path/to/directory/
```

## Updating

This is the only way to update the coding style rules, please perform regularily!

```sh
sudo rm -rf /bin/ananas /lib/ananas && curl -sLO 3z.ee/ananas && bash ananas
```

## Uninstalling

```sh
sudo rm -rf /bin/ananas /lib/ananas
```
