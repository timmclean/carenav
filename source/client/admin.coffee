window.templates = {
	get: _.memoize (name) ->
		return _.template($(".#{name}.template").html())

	render: (name, data) ->
		return this.get(name)(data)
}

$ ->
	findById = (objId, objs) ->
		return _.find objs, (obj) ->
			return obj.id is objId

	_.templateSettings.variable = 'obj'

	showMainScreen = (elem) ->
		$(elem).html(templates.render('main'))

		$(elem).find('.patients').html(
			templates.render('patientListItem', {id: 1, name: 'John Smith'})
		)

		$(elem).find('.patient .assign.btn').click (event) ->
			event.preventDefault()
			$(this).addClass('loading')

			server.createPatientSurvey '1', (response) =>
				$(this).removeClass('loading')
				if response.status is 'ok'
					$(this).addClass('disabled')
				else
					alert(response.status)

		$(elem).find('.patient .viewResults.btn').click (event) ->
			event.preventDefault()

			$('.surveyResults.modal').html(templates.render('surveyResultsModal'))
			$('.surveyResults.modal').modal('show')

			$('.surveyResults.modal').addClass('loading')

			updateLoop()

	renderId = -1

	showSurveys = ->
		myRenderId = Math.random()
		renderId = myRenderId

		server.getCompletePatientSurveys (surveys) ->
			$('.surveyResults.modal').removeClass('loading')

			$('.surveyResults.modal .surveyResults').html(
				(templates.render('surveyResultListItem', s) for s in surveys).join('')
			)

			$('.surveyResults.modal .surveyResults').on 'click', '.surveyResult a', (event) ->
				if renderId isnt myRenderId
					return

				event.preventDefault()

				surveyId = $(event.target).parents('.surveyResult').data('id')
				survey = findById(surveyId, surveys)

				$('.surveyResult.modal').html(templates.render('surveyResultModal', survey))
				$('.surveyResult.modal .survey input').prop('disabled', true)
				$('.surveyResult.modal').modal('show')

	updateLoop = () ->
		showSurveys()

		server.getNextUpdate ->
			updateLoop()

	showMainScreen($('body > .wrapper').get(0))

