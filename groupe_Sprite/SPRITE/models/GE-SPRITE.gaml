/**
 *  kaolla
 *  Author: carole
 *  Description: 
 */

model kaolla

/* Insert your model definition here */


global {
	
	int budget <- 2;
	
	bool phase_inondation <- false;
	bool phase_retrait <- false;
	bool nouveau_tour <- false;
	
	// nombre de cellules inondees
	int nombreInondees <- 0 update: length((parcelle where (each.cptInondations>0)));
	
	// securite moyenne
	int avgSecu <- 0 update: mean(parcelle collect each.valeurSecurite);
	// somme des populations des cellules de secu < 3
	int nbHabInsecure <- 0 update: sum((parcelle where (each.valeurSecurite < 2)) collect each.nbHabitants) / sum(parcelle collect each.nbHabitants) * 100;
	
	// valeur ecologique moyenne
	int avgEcolo <- 0 update: mean(parcelle collect each.valeurEcolo);
	
	
	init {
		write 'alerte a oleron, c\'est parti';
		
		ask parcelle {
			do updateSecu;
		}
		
	}
	
		// submersion
	reflex transition1 when: world.budget=0 {
		world.phase_inondation <- true;
	}
	
	reflex debug {
		int combien_parcelles <- length(parcelle where (each.valeurSecurite<3));
		write 'combien parcelles = '+combien_parcelles;
		
		int combien_habitants <- sum((parcelle where (each.valeurSecurite < 2)) collect each.nbHabitants);
		write 'combien habitants = '+combien_habitants;
		
		int population_totale <- sum(parcelle collect each.nbHabitants);
		write 'population totale = '+population_totale;
		
		float proportion <- combien_habitants / population_totale;
		write 'proportion = '+proportion;
	}
	
	// action de submersion, force random
	action submerge {
		int importance <- 1+rnd(3);
		write 'SUBMERSION !!! force '+importance;
		// parcelles dont distance a la mer < importance
		ask parcelle {
			// nombre de cellules mer a proximite
			int mer <- length((parcelle where each.is_sea) at_distance importance );
			write 'mer = '+mer; //(each distance_to ((parcelle where (each.is_sea)) closest_to(self))<importance) {
			if ((mer>0) and valeurSecurite<2 and (rnd(1)=1)) {
				inondee <- true;
				cptInondations <- cptInondations+1;
			}
		}
	}
	
	// action de fin submersion
	action fin_submersion {
		ask parcelle {
			inondee <- false;
		}
	}
	
	user_command submersion {//when: world.phase_inondation {
		ask world {
			do submerge;
			world.phase_inondation<-false;
			world.phase_retrait<-true;
		}
	}
	
	user_command finsub {  //when: world.phase_retrait {
		ask world {
			do fin_submersion; 
			world.phase_retrait<-false;
			world.nouveau_tour<-true;
		}
	}
	
	user_command reinit_budget {  //when:nouveau_tour {
		budget<- 2;
		write 'Une nouvelle annee commence, ton budget est de 2';
		world.nouveau_tour<-false;
	}
	
	
	
}


grid parcelle width: 25 height: 25 neighbours: 8 use_regular_agents: true use_individual_shapes: false use_neighbours_cache: false {
	
	// inondee ?
	bool inondee <- false;
	int cptInondations <- 0;
	
	// digue ecolo
	bool hasBriseLame <- false;
	
	// digue
	bool hasDyke <- false;
	
	// mer ou terre ?
	bool is_sea <- (grid_x<5 or grid_x>20 or grid_y<5 or grid_y>20)?true:false;
	
	// nombre habitants 
	int nbHabitants <- is_sea?0:rnd(10)*rnd(1);
	
	// indicateurs de la parcelle (init random)
	int valeurSecurite <- 0; //rnd(10);
	int valeurEcolo <- rnd(10);
	
	// action de l'utilisateur
	
	// construction de digue non ecolo (protection++, ecolo--)
	user_command "construire une digue en béton"
	{
		if (world.budget>0) {
			hasDyke <- true;
			budget <- budget-1;
		} 
		else {
			write 'PLUS DE BUDGET !!';
		}
	}	
	
	user_command "construire un brise lame"
	{
		if (budget>0) {
			hasBriseLame <- true;
			budget <- budget-1;
		} 
		else {
			write 'PLUS DE BUDGET !!';
		}
	}
	
	user_command "ajouter habitants" {
		//user_input "Number" returns: number type: int <- 10;
		if (budget > 0) {
	        nbHabitants <- nbHabitants+1;
	    	budget <- budget-1;
	    }
	    else {
	    	write 'PLUS de BUDGET';
	    }
	}

	user_command "depart habitants" {
		//user_input "Number" returns: number type: int<-10;
		if (budget>0) {
			nbHabitants <- max([0,nbHabitants-1]);
			budget <- budget-1;
		}
	}
	
	action updateSecu {
		
		// distance a la mer
		parcelle p1 <- (parcelle where (each.is_sea)) closest_to(self);
		//write 'parcelle 1 = ' +p1;
		int distanceSea <- self distance_to ( p1 );
		// valeur de securite de la cellule
		valeurSecurite <- distanceSea; 
		  
		//int distanceSea <- 1;  
		   
		// distance a la digue la plus proche (ou 15 si pas encore de digue)
		list<parcelle> lp <- self neighbours_at 2;
		if (!empty(lp where each.hasDyke)) {valeurSecurite <- valeurSecurite+7;}
		if (!empty(lp where each.hasBriseLame)) {valeurSecurite <- valeurSecurite+3;}
		
		/*parcelle p2 <- (parcelle where (each.hasDyke or each.hasBriseLame)) closest_to(self);
		if (hasDyke or hasBriseLame) {p2 <- self;}
		if (p2 = nil) {p2<-any(parcelle at_distance 15);}
		//write 'parcelle 2 = '+p2;
		int distanceDigue <- self distance_to (p2); */
	
		//if (distanceDigue<2) { valeurSecurite <- valeurSecurite-4;}
	}
	
	reflex updateSecu {
		do updateSecu;
	}
	
	reflex updateEcolo {
		//if (hasDyke) {valeurEcolo <- valeurEcolo+8;}
		//if (hasBriseLame) {valeurEcolo <- valeurEcolo+4;}
		
		// self est-il dans les neighbours??
		list<parcelle> lp <- self neighbours_at 2;
		if (!empty(lp where each.hasDyke)) {valeurEcolo <- valeurEcolo-8;}
		if (!empty(lp where each.hasBriseLame)) {valeurEcolo <- valeurEcolo-4;}
	}
	
	

	
	
	action draw_stuff {
		if (nbHabitants>0) { draw square(nbHabitants/5) color:#orange;}
		if (hasDyke) { draw triangle(2) color:#yellow;}
		if (hasBriseLame) { draw triangle(2) color:#green;}
	}
	
	aspect secu {
		rgb ze_colour <- (is_sea or inondee)?#blue:rgb(255,valeurSecurite*25.5,valeurSecurite*25.5);
		draw square(self.shape.perimeter/4) color : ze_colour;
		do draw_stuff;
	}
	
	aspect ecolo {
		rgb ze_colour <- (is_sea or inondee)?#blue:rgb(255-valeurEcolo*25.5,255,255-valeurEcolo*25.5);
		draw square(self.shape.perimeter/4) color : ze_colour;
		do draw_stuff;
	}
	
	// indicateur de securite : fonction du nombre d'habitants en insecurite
	// valeur ecologique moyenne de l'ile
		
}

experiment Displays type: gui
{
//Definition de quelques parametres
	//parameter "Phase de submersion ?: " var: phase_sub;
	output
	{
		// carte de securite en rouge
		display map_secu ambient_light: 100 
		{ 
			grid parcelle triangulation: false lines: # black ; 
			species parcelle aspect: secu ;
			//species dyke aspect:triangle;
		}
		
		
		// carte ecolo
		display map_ecolo ambient_light:100
		{
			grid parcelle triangulation: false lines: #black;
			species parcelle aspect:ecolo;
		}
		
		// graphiques
		display securite { 
			chart "Securite" type: series
			{
				data "nombre d'habitants en insecurite" value: world.nbHabInsecure color : °yellow;
			}
		}		
		display ecologie {
			chart "Ecologie" type:series
			{
				data "valeur ecologique moyenne de l'ile" value: world.avgEcolo color: #green;
			}
		}
		
	}
	
}