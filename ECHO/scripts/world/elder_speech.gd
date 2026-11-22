class_name ElderSpeech
extends RefCounted
## K's closing words, built from how this player actually played. It reflects, never judges.

static func lines(progress: Dictionary) -> Array:
	var stats: Dictionary = progress.get("stats", {})
	var minutes := int(float(stats.get("play_time", 0.0)) / 60.0)
	var wrong := int(stats.get("wrong_notes", 0))
	var startles := int(stats.get("startles", 0))
	var scares := int(stats.get("scares", 0))
	var chord_pings := int(stats.get("chord_pings", 0))
	var freed := 0
	for blob_id in progress.get("freed", {}):
		if not str(blob_id).begins_with("vassal"):
			freed += 1
	var areas: Array = progress.get("areas_entered", [])
	var area_names := {"vista": "pelas Grutas, no escuro", "som": "pelo Vale, a ouvir", "tato": "pelo Bosque, devagar"}

	var result: Array = [
		["K", "...Aqui estou. Sem pedaços em falta."],
		["K", "Eu sou a K. A cor mais escura, a que dá forma a todas as outras."],
		["K", "Quando deixámos de nos ouvir uns aos outros, fechei-me. E as cores foram-se comigo."],
		["K", "Fui eu que te guiei. Mas fui também uma das que precisava de ser encontrada."],
	]
	if not areas.is_empty() and area_names.has(areas[0]):
		result.append(["K", "Começaste %s. Interessante... cada um começa pelo sentido em que mais confia." % area_names[areas[0]]])
	result.append(["K", "Ajudaste %d criaturas, em cerca de %d minutos." % [freed, maxi(minutes, 1)]])
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
	result.append(["K", "Obrigada por ouvires."])
	return result
