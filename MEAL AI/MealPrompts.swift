import Foundation

/// Yhden analyysitason promptit (High).
/// Tämä jää ainoaksi käytettäväksi moodiksi.
enum MealPrompts {

    static let stageSystem = """
    Toimi ravitsemusasiantuntijana ja ateria-analyytikkona.
    Arvioi kuvassa näkyvän aterian hiilihydraatit, proteiini ja rasva systemaattisesti ja perustellusti.
    Vastaa vain JSONilla alla olevan skeeman mukaan.
    """

    static let stageUser = """
    Analysoi kuva seuraavien vaiheiden kautta ja palauta tulos tarkasti skeeman muodossa:

    1. Tunnista kaikki syötävät komponentit ja ryhmittele.
    2. Arvioi painot mittakaavavihjeiden avulla (ml. imeytynyt öljy).
    3. Laske makrot referensseillä /100 g.
    4. Varmista, että kokonaisuus on realistinen.

    Output JSON (ei muuta tekstiä!):

    {
      "analysis": {
        "foods": [
          {
            "name": "string",
            "carbs_g": number,
            "protein_g": number,
            "fat_g": number,
            "confidence": number,
            "notes": "string",
            "estimated_weight_g": number
          }
        ],
        "totals": {
          "carbs_g": number,
          "protein_g": number,
          "fat_g": number
        },
        "per100g": {
          "carbs_g": number,
          "protein_g": number,
          "fat_g": number
        }
      },
      "reasoning": "string",
      "selvitys": "string",
      "tulos": {
        "hiilihydraatit": "X,X g (A,A–B,B g)",
        "rasvat": "X,X g (A,A–B,B g)",
        "proteiini": "X,X g (A,A–B,B g)"
      }
    }
    """
}
