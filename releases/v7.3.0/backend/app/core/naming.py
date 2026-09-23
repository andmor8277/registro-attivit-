def format_cognome(val):
    if not val:
        return val
    return val.upper()


def format_nome(val):
    if not val:
        return val
    return ' '.join(w[:1].upper() + w[1:].lower() for w in val.split())
