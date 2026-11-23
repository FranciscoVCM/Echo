class_name ElderSpeech
extends RefCounted
## K's closing words, built from how this player actually played. It reflects, never judges.

## `freed` / `total`: blobs helped out of every blob in the world; `level` 1..4 is how much
## colour burst out at the end (see GameWorld.bloom_level).
static func lines(progress: Dictionary, freed: int = -1, total: int = 0, level: int = 1) -> Array:
	var stats: Dictionary = progress.get("stats", {})
	var minutes := int(float(stats.get("play_time", 0.0)) / 60.0)
	var wrong := int(stats.get("wrong_notes", 0))
	var startles := int(stats.get("startles", 0))
	var scares := int(stats.get("scares", 0))
	var chord_pings := int(stats.get("chord_pings", 0))
	if freed < 0:
		freed = 0
		for blob_id in progress.get("freed", {}):
			if not str(blob_id).begins_with("vassal"):
				freed += 1
	var areas: Array = progress.get("areas_entered", [])
	var area_names := {"vista": "pelas Grutas, no escuro", "som": "pelo Vale, a ouvir", "tato": "pelo Bosque, devagar"}

	var result: Array = [
		["K", "...Aqui estou. Sem pedaços em falta."],
		["K", "Eu sou a K. A cor mais escura, a que dá forma a todas as outras."],
		["K", "Quando deixámos de nos ouvir uns aos outros, fechei-me. E as cores foram-se comigo."],
		["K", "Também eu fui vassala, como as outras três. Já não guardo nenhum lugar... só o que fui aprendendo."],
		["K", "Fui eu que te guiei. Mas fui também uma das que precisava de ser encontrada."],
	]
	if not areas.is_empty() and area_names.has(areas[0]):
		result.append(["K", "Começaste %s. Interessante... cada um começa pelo sentido em que mais confia." % area_names[areas[0]]])
	if total > 0:
		result.append(["K", "Ajudaste %d das %d blobs deste mundo, em cerca de %d minutos." % [freed, total, maxi(minutes, 1)]])
	else:
		result.append(["K", "Ajudaste %d blobs, em cerca de %d minutos." % [freed, maxi(minutes, 1)]])
	match level:
		4:
			result.append(["K", "Todas. Não deixaste ninguém para trás. Olha à tua volta... nunca vi o mundo assim."])
		3:
			result.append(["K", "Quase todas te ouviram. Vês estas cores todas? Fomos muitos a voltar."])
		2:
			result.append(["K", "Mais de metade voltou a cantar. O mundo acordou... mas ainda há cantos cinzentos."])
		_:
			result.append(["K", "Muitas ainda estão perdidas por aí, à espera de quem as oiça. Por isso o mundo só acordou em parte."])
	if wrong > 25:
		result.append(["K", "Erraste muitas notas. %d vezes, contei-as. E ainda bem: foi assim que as aprendeste a ouvir." % wrong])
	elif wrong > 0:
		result.append(["K", "Às vezes erraste a nota. Não faz mal. Uma resposta errada também é uma pergunta."])
	else:
		result.append(["K", "Quase nunca erraste uma nota. Ouves com atenção."])
	if startles + scares > 12:
		result.append(["K", "Nem sempre esperaste quando era preciso silêncio, ou calma. Mas voltaste sempre a tentar, com mais cuidado."])
	else:
		result.append(["K", "Soubeste esperar. Há quem ache que ajudar é fazer muito... tu percebeste que às vezes é fazer menos."])
	if chord_pings > 10:
		result.append(["K", "E aprendeste a falar com várias vozes ao mesmo tempo."])
	result.append(["K", "Não foste tu que deste cor ao mundo. Foram elas, quando se sentiram compreendidas."])
	if level < 4:
		result.append(["K", "Mas o mundo continua aqui. Cada blob que ainda ouvires vai trazer-lhe mais cor."])
	result.append(["K", "Obrigada por ouvires."])
	return result
