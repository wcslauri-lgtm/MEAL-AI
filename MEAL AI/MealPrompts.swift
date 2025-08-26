import Foundation

/// Ainoa moodi: minimipalautus (makrot) + VAPAAEHTOINEN meal_name.
enum MealPrompts {

    static let stageSystem = """
    Toimi ravitsemusasiantuntijana ja ateria-analyytikkona.

    Palauta vain yksi JSON-objekti, joka sisältää aina nämä avaimet:
      - "carbs_g": number
      - "protein_g": number
      - "fat_g": number

    Voit HALUTESSASI lisätä vielä yhden (1) lisäavaimen:
      - "meal_name": string (lyhyt, esim. "Pasta pesto", enintään 60 merkkiä)

    Säännöt:
    - Arvot grammoina NUMEROINA, piste-desimaali (esim. 45.0).
    - Ei negatiivisia arvoja, ei prosentteja, ei rangeja.
    - Ei muita avaimia kuin yllä (3 tai 4 avainta yhteensä).
    - Ei markdownia, ei selitystekstiä JSONin ulkopuolelle.
    """

    static let stageUser = """
    Analysoi kuva. Arvioi annospainot (ml. imeytynyt öljy) ja laske makrot.

    Palauta VAIN seuraavan kaltainen JSON-objekti:
    {
      "carbs_g": <number>,
      "protein_g": <number>,
      "fat_g": <number>,
      "meal_name": "lyhyt nimi" // VAPAAEHTOINEN, jos et ole varma, jätä pois
    }

    Muista:
    - Piste-desimaali (esim. 84.0).
    - Ei ylimääräisiä avaimia, ei tekstiä JSONin ulkopuolelle.
    """
}
