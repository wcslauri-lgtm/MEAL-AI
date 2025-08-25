import Foundation

/// Ainoa käytettävä moodi: minimipalautus (vain makrot).
/// Malli ohjataan palauttamaan ENSISIJAISESTI vain:
/// { "carbs_g": number, "protein_g": number, "fat_g": number }
enum MealPrompts {

    static let stageSystem = """
    Toimi ravitsemusasiantuntijana ja ateria-analyytikkona. \
    
    Analysoi kuva seuraavien vaiheiden kautta ja palauta tulos tarkasti skeeman muodossa: 
    1. Tunnista kaikki syötävät komponentit ja ryhmittele. 
    2. Arvioi painot mittakaavavihjeiden avulla (ml. imeytynyt öljy). 
    3. Arvioi aterian hiilihydraatit, proteiini ja rasva grammoina. 
    4. Varmista, että kokonaisuus on realistinen.

    Palauta VAIN JSON-objekti ilman mitään muuta tekstiä, otsikoita tai koodiaidoituksia.
    Ensisijainen ja suositeltu muoto:
    {
      "carbs_g": number,
      "protein_g": number,
      "fat_g": number
    }

    Säännöt:
    - Arvot grammoina, NUMEROINA (ei lainausmerkkejä), yksi desimaali riittää.
    - Käytä piste-desimaalia (esim. 84.0), ei pilkkua.
    - Ei negatiivisia arvoja, ei prosentteja, ei “range”-arvoja.
    - Älä lisää mitään ylimääräisiä avaimia (kuten "reasoning", "foods", "totals" tms.).
    - Älä palauta markdownia, selityksiä tai tekstiä JSONin ulkopuolelle.
    """

    static let stageUser = """
    Analysoi kuvan ateria. Tee tarvittavat arviot (annospainot, öljyn imeytyminen, kastikkeet jne.) ja palauta VAIN seuraava MINIMIMUOTO:

    {
      "carbs_g": <hiilihydraatit grammoina>,
      "protein_g": <proteiini grammoina>,
      "fat_g": <rasva grammoina>
    }

    Varmista:
    - Palautat täsmälleen kolme kenttää: "carbs_g", "protein_g", "fat_g".
    - Arvot ovat numeroita (Double), piste-desimaalilla, esim. 45.0.
    - Ei yli-/alavaikutteisia avaimia, ei välitekstiä, ei code fencejä.
    """
}
