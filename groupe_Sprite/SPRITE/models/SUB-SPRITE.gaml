/**
 *  SPRITE
 *  Author: Mog
 *  Description: 
 */
//tac tac
model SPRITE

/* Insert your model definition here */



/***********************************************
 *                   AGENT MONDE               * 
 ***********************************************/

global
{
	// *************************** VARIABLES AGENT MONDE **********************
	
	//chargement des données géographiques
	file island_shapefile <- file("../includes/contours_ile.shp");
	file sea_shapefile <- file("../includes/mer3.shp");
	file dykes_shapefile <- file("../includes/ouvrages.shp");
	file buildings_shapefile <- file("../includes/batiments.shp");
	file dem_file <- csv_file("../includes/mnt_small.csv", " ");

	//définition des géométries
	geometry shape <- envelope(file("../includes/rect.shp"));
	geometry lamer <- geometry(first(island_shapefile));
	geometry sea <- geometry(sea_shapefile);
	
	//définition des cellules de mer
	list<parcelle> sea_cells;
   	list<parcelle> merProche;
   	list<parcelle> premiercercledelamer;
   	list<parcelle> toutpremiercercledelamer;
   	list<parcelle> cellulesquiserventarien;
   	list<parcelle> cellulesquiserventaquelquechose;
	list<parcelle> cellulessanseau;

	
	// securite moyenne
	int avgSecu <- 0 update: mean(parcelle collect each.valeurSecurite);
	
	// somme des populations des cellules de secu < 3
	int nbHabInsecure <- 0 update: sum((parcelle where (each.valeurSecurite < 2)) collect each.nbHabitants) / sum(parcelle collect each.nbHabitants) * 100;
	
	// valeur ecologique moyenne
	int avgEcolo <- 0 update: mean(parcelle collect each.valeurEcolo);

	//un bool utiliser pour lancer le reflexe de flood TRUE = flowing
	bool phase_sub <- false;

	//********************* PARTIE MAIRIE ******************************
	float taux_impots <- 0.1;
	float dommageTotal;
	int budget update: sum(parcelle collect each.impots);

	//********************* PARTIE SUBMERSION DU GLOBAL*****************
	//définition des paramètres du modèle
	// taux de diffusion de l'eau d'une case à une autre - paramètre à recaller
	float diffusion_rate <- 0.6;
	float hauteur_eau;
	int temps_submersion;

	//paramètre des digues 
	float dyke_height;
	float dyke_width;

	
	//***************** INITIALISATION AGENT MONDE *********************
	init 
	{
	write 'Alerte a oleron, c\'est parti';
		
	// l'utilisateur (agent controle par le joueur via des boutons)
	//create user;
		do init_cells;
		do init_water;
		do init_obstacles;
		create territoire number:1 ;
		
		ask cellulesquiserventarien {already <- true;}
		cellulesquiserventaquelquechose <- parcelle - cellulesquiserventarien;
		ask parcelle
		{
			do update_color;
		}
		
		do placer_digues_maisons;
			ask (parcelle) {
	 			color <- # white;
		if (is_sea) {color <- # blue;}
	 	eau_present<-false;
	 	
	 	}
	}
	// fin init


	//**************REFLEXE AGENT MONDE********************
	reflex {
		dommageTotal<-0.0;
		ask (parcelle) {
	 		color <- # white;
			if (is_sea) {color <- # blue;}
	 			eau_present<-false;
	 			dommage<-0.0;
	 	}
	}


	//initialisation des cellules de la grille a partir du shapefile
	action init_cells
	{
		matrix data <- matrix(dem_file);
		ask parcelle
		{
			altitude <- float(data[grid_x, grid_y]);
			altitude <- max([-2, altitude]);
			//int alt_color <- max([0, min([255, int(255 * (1 - (3 + altitude) / 25))])]);
			//color <- rgb([alt_color, 255, alt_color]);
			color <- #blue;
			neighbour_cells <- (self neighbours_at 1);
			neighbour_cells_far <- (self neighbours_at 2);
		}
	}

	//initialisation de la mer a partir du shapefile
	action init_water
	{	
		ask parcelle overlapping sea
		{
			water_height <- hauteur_eau;
			is_sea <- true;
		}

		sea_cells <- parcelle where (each.is_sea);
		premiercercledelamer <- sea_cells where each.celluleterrecote;
		loop act over: premiercercledelamer {
			act.is_sea <- false;
		}
		cellulessanseau <- parcelle - sea_cells;
	}


	//initialisation des bâtiments et des digues a partir du shapefile
	action init_obstacles
	{
	//création des bâtiments à partir des fichiers géo
		create building from: buildings_shapefile
		{
			do update_cells;
		}

		//création des bâtiments à partir des fichiers géo (avec récup de la hauteur et de l'état)
		create dyke from: dykes_shapefile with: [hauteur::float(read("hauteur")), etat::string(read("Etat_Ouvra"))];
		ask dyke
		{
		// passage de mm (dans fichier) à des m
			height <- hauteur / 100;
			shape <- shape + dyke_width;
			
			if height<3 {typeDick<-1;} else {typeDick<-2;}
			do update_cells;
		}

		//parcelle closestSea<- ((parcelle where (each.is_sea)) closest_to(self));  
  		float distanceSea<- self distance_to sea; 
   
   //merProche <- parcelle where (each.distanceSea=0 and each.is_sea);
	//write(length(merProche));
	}

	//renseigne sur la présence de digue sur une cellule
	action placer_digues_maisons
	{
		//ask parcelle overlapping dyke
		//{
		//	digue <- true;
		//}
		ask parcelle overlapping building {
			maison <- true;
			bats <- building overlapping self;
			//surface d'une cellule 200x200 et surface_maison, taux de surface couverte par le bati en %
			densite_bati <- sum(bats collect each.shape.area) / 400;
		}
	}

/* 	action color_bati {
		ask parcelle {
			if not empty(building overlapping self) {
				maison <- true;
				bats <- building overlapping self;
				//surface d'une cellule 200x200 et surface_maison, taux de surface couverte par le bati en %
				surface_maison <- sum(bats collect each.shape.area) / 400;
			}
		}
	}
*/
	//régénartion de l'eau dans les cellules de mer (pour simuler le remplacement de l'eau)
	action adding_input_water
	{
		float water_input <- rnd(100) / 100;
		ask premiercercledelamer//sea_cells
		{
			water_height <- water_height + water_input;
		}

	}

	//mécanisme de submersion  -demande de propagation aux cellules
	action flowing
	{	ask cellulesquiserventaquelquechose
		{
			already <- false;
		}
		ask (cellulesquiserventaquelquechose sort_by ((each.altitude + each.water_height + each.obstacle_height)))
		{
			do flow;
		}
		
	}
	

	//mise à jour de la couleur des cellules en fonction de l'eau
	action update_cell_color 
	{
		ask parcelle
		{
			do update_color;
		}
	}

	
	// SUUUBBBBBMMMMEEEERRRRSSSIIIIOOOONNNNNNN
	action submerge {
	hauteur_eau <- rnd(10)/5 # m;
	temps_submersion <- 5;
	//boucle de submersion
		loop i from : 0 to : temps_submersion-3 {
		//	list<parcelle> actives <- parcelle where (each.water_height > 0.0 and );
		//flowing
			do adding_input_water;
			do flowing;
					//ask dyke {do breaking_dynamic;}
		ask parcelle {do releveStatSubm;}
		//condition de fin - a partir de t>tfin, la diffusion diminue
			if i > temps_submersion
			{
				diffusion_rate <- max([0, diffusion_rate - 0.1]);
			}
		do 	update_cell_color;
		}

		ask parcelle{
		color <- # white;
		if (is_sea) {color <- # blue;}
		if (eau_present=true) {
				nbSubmersion<-nbSubmersion+1;
				color <-#blue;
				dommage<-densite_bati;
				dommageTotal<-dommageTotal+dommage;
				}
		 	}	 	
	//write dommageTotal;
	}
	

	user_command reinit_budget {  //when:nouveau_tour {
	budget<- 2;
	write 'Une nouvelle annee commence, ton budget est de 2';
	//world.nouveau_tour<-false;
	}


		
	
	// commande pour que l'utilisateur lance la submersion
	user_command "submerger" {
		write "SUBMERSION !!!!!!!";
		do submerge;
	}


}
/* ******************************************************************
 ******* fin global *******                                       ***
*********************************************************************/

species territoire {
	//********************* PARTIE MAIRIE ******************************
	float taux_impots <- 0.1;
	int budget update: sum(parcelle collect each.impots);
	
	// surface habitable = nombre de cellules terrestres * densite bati
	// pourcentage bati de l'ile
	float surface_habitable {
		sum ((parcelle where !each.is_sea) collect each.densite_bati)
	}

	//  20000 habitants en tout / surface habitable = population max par cellule
	// nb d'habitants par %age de surface batie 
	float densite_population {
		surface_habitable/20000
	}
	
	//dommage
	float dommageTer;
	
	// population totale
	

	/**********************************
	 * *** CALCUL DES INDICATEURS *** *
	 **********************************/
	 
	 // popularite en fonction de la satisfaction ponderee de chaque cellule (satisfaction*densite population)
	float indicateurPopularite
	{
		sum(parcelle collect each.satisfactionPonderee) / sum(parcelle collect each.densite_bati)
	}
	
	// indicateur de securite du territoire = moyenne de securite des cellules
	float indicateurSecuriteMoyenne
	{
		mean(parcelle collect each.valeurSecurite)
	}
	
	// indicateur de securite minimum
	float indicateurSecuriteMinimale
	{
		min(parcelle collect each.valeurSecurite)
	}


	
}


/********************************
* OBSTACLES : maisons et digues *
*********************************/

//spécification des obstacles et maison
species obstacle
{
	float height min: 0.0;
	string etat;
	rgb color;
	int typeDick;
	float water_pressure update: compute_water_pressure();
	list<parcelle> cells_concerned;
	list<parcelle> cells_neighbours;
	float compute_water_pressure
	{
		if (height = 0.0)
		{
			return 0.0;
		} else
		{
			if (not empty(cells_neighbours))
			{
				float water_level <- cells_neighbours max_of (each.water_height);
				return min([1.0, water_level / height]);
			}

		}

	}

	action update_cells
	{
		cells_concerned <- (parcelle overlapping self);
		ask cells_concerned
		{
			digue<-myself.typeDick;
	
		}

		cells_neighbours <- cells_concerned + cells_concerned accumulate (each.neighbour_cells);
		do compute_height();
		if (height > 0.0)
		{
			water_pressure <- compute_water_pressure();
		} else
		{
			water_pressure <- 0.0;
		}

	}

	// ???
	action compute_height;
	aspect geometry
	{
		int val <- int(255 * water_pressure);
		color <- rgb(val, 255 - val, 0);
		draw shape color: color depth: height border: color;
	}

}

species building parent: obstacle
{
	float height <- 2.0 + rnd(8);
}

species dyke parent: obstacle
{
	int counter_wp <- 0;
	int hauteur;
	int breaking_threshold <- 24;

	// s'agit-il d'une digue ecologique ou pas
	bool est_ecolo;
	
	action break
	{
		ask cells_concerned
		{
			do update_after_destruction(myself);
		}

		do die;
	}

	// FIXME: est-ce qu'il faut copier la meme action dans building?
	// dans ce cas il faut plutot la mettre dans l'espece parente = obstacle
	action compute_height
	{
		height <- dyke_height - mean(cells_concerned collect (each.altitude));
	}

	action breaking_dynamic
	{
		if (water_pressure = 1.0)
		{
			counter_wp <- counter_wp + 1;
			if (counter_wp > breaking_threshold)
			{
				do break;
			}

		} else
		{
			counter_wp <- 0;
		}
	}
	aspect triangle {
		rgb couleur <- #black;
		if (est_ecolo) {couleur <- #green;}
		else {couleur <- #yellow;}
		

	}

}




/***************************************
 * ******* GRILLE DE PARCELLES ******* *
 ***************************************/

grid parcelle width: 52 height: 90 neighbours: 8 frequency: 0 use_regular_agents: false use_individual_shapes: false use_neighbours_cache: false
{
	/***************************Variables pour flood****************************************/

	// altitude d'apres le MNT
	float altitude;

	// hauteur d'eau sur la cellule
	float water_height <- 0.0 min: 0.0;
	bool eau_present<- false;
	
	// hauteur du plus haut obstacle si plusieurs
	float obstacle_height <- 0.0;

	// hauteur totale agreegee = altitude + hauteur bati + hauteur eau
	float height;

	// cellules voisines (Moore, 8)
	list<parcelle> neighbour_cells;
	list<parcelle> neighbour_cells_far;
		
		
	// cellule mer / terre 
	bool is_sea <- false;

	bool celluleterrecote function: {((self neighbours_at 2) first_with not each.is_sea) != nil};
   	// parcelle de mer la plus proche et distance à la mer 
   	parcelle closestSea;
   	float distanceSea;

	// liste des obstacles situes sur cette cellule      
	list<obstacle> obstacles;

	// est-ce que la cellule a deja ete traitee dans la diffusion de l'eau
	bool already <- false;

	// calculer la hauteur du plus haut obstacle present sur cette cellule
	float compute_highest_obstacle
	{
	// si aucun obstacle : hauteur nulle
		if (empty(obstacles))
		{
			return 0.0;
		}
		// sinon renvoyer le max
		else
		{
			return obstacles max_of (each.height);
		}
	}

	/****************************Variables interactions parcelles **********************/

	// 0 : pas de digue, 1 : petite digue, 2 : grosse digue
	int digue <- 0;
	territoire mon_territoire <- any(territoire);
	// il est possible de construire sur cette parcelle (pas en zone noire)
	bool constructible <- true;
	float dommage;
	// il y a une maison sur cette parcelle
	list<building> bats;
	float densite_bati <- 0.0;
	float nbHabitants <-0.0;
	bool maison update: densite_bati > 0;

	// valeur ecologique
	int valeurEcolo <- rnd(10) min: 0 max: 10;

	// valeur attractivite
	int valeurAttractivite <- rnd(10) min: 0 max: 10;

	//valeur securite
	float valeurSecurite <- 0.0;
	

	//valeur information : connaissance du risque
	int information <- rnd (10) min: 0 max:10; 
	
	// valeur historique: submersion 
	//int nbSubmersion <- 0 ;
	//int maxHauteur <- 0;
	
	// valeur politique (accord avec actions du maire)
	int valeurPolitique <- rnd(10);

	// impots donnes par cette parcelle a la mairie en fonction de sa population + attractivite (retombees touristiques)
	// FIXME : a quel territoire appartient cette parcelle
	float impots update: valeurAttractivite + any(territoire).taux_impots * densite_bati;

	// satisfaction ecologique inversement proportionnelle a la distance vers la plus proche cellule de haute valeur ecologique
	// attention closest_to n'est pas optimise
	//cell closestBeach <- ((cell where (each.valeurEcolo>7)) closest_to(self));  
	//float distanceBeach <- self distance_to closestBeach;

	/*int satisfNormalisee  {
		if (distanceBeach <= 2) {return 1;}
		else if (distanceBeach <=5) { return 0.5;}
		else {return 0;}
	}*/


	//valeur information : connaissance du risque (en reponse aux actions d'information du maire)
	//int information <- rnd (10) min: 0 max:10; 
	
	// valeur historique: submersion 
	int nbSubmersion <- 0 ;
	float maxHauteur <- 0;
	
	// en cours : closest sea et closest dyke sont nulles
	// peut etre digues pas encore crees a ce moment
	
	// distance a la mer (pour securite-- et attractivite++)
	float distanceSea  {
		//list<parcelle> seaCells <- parcelle where (each.is_sea);
		if (!empty(sea_cells)) {
			parcelle closestSea <- (sea_cells closest_to(self));  
	   		return self distance_to closestSea;
	   	}
	   	else {
	   		return 10000;
	   	}
	}	
	
	float distanceDigue {
		dyke closestDyke <- dyke closest_to(self);
		if (closestDyke = nil) {return 10000;}
		else {return self distance_to (closestDyke);}
	}
	

// la satisfaction des habitants de cette parcelle est la somme des 3 indices (secu, ecolo, attractivite)
	float valeurSatisfaction function: { (valeurSecurite + valeurAttractivite + valeurEcolo + valeurPolitique) / 4 };

	// satisfaction ponderee par la population - valeur entre 0 et 1000 (densite bati entre 1 et 100)
	float satisfactionPonderee
	{
		valeurSatisfaction * densite_bati
	}
	


	
	
	/*********************************
	 * *** REFLEXES DE LA PARCELLE ***
	 *********************************/

	// 3 valeurs
	// - securite
	// secu augmente avec digues (++ si vraie digue, + si digue ecolo) et avec densite population et actions information
	// secu diminue avec proximite a la mer, et avec frequence/recence/gravite (ie hauteur d'eau) de la derniere inondation
	// - ecologie
	// ecolo augmente avec actions conservation et avec expropriation (direct par non constructibilite, indirect par diminution densite population)
	// ecolo diminue (--) avec digue standard, diminue un peu (-) avec digue ecolo, diminue avec densite population
	// - attractivite
	// attract augmente avec action promotion, avec proximite mer
	// attract diminue avec digues standard et avec densite population
	
	// valeur d'impots de la parcelle depend de population et de attractivite (retombees touristiques)

	// reflexe pour la mise a jour de la valeur ecologique a chaque tour
	reflex updateValeurEcolo when: phase_sub
	{
	// si pas de digue : augmente

	// si digue ou toute construction : diminue

	// non constructibilite : augmente
	}

	// reflexe pour la mise a jour de la valeur touristique a chaque tour
	reflex updateValeurAttractiv when: phase_sub
	{
	// proximite a la mer, constructibilite
	}

	// reflexe pour la mise à jours de la valeur de securité à chaque tour 
	// depend des digue, de l'information,densite
	reflex updateValeurSecurite //when: !phase_sub
	{
		float secuDigue <- 0.0;
		// si aucune digue : securite 0
		if (digue=0) {secuDigue <- 0.0;}
		// si une ou plusieurs digues
		else {
			// s'il y a une vraie digue non ecolo : securite max
			if (digue=2) {secuDigue <- 10.0;}
			// sinon (digues ecolos / brise lame : securite moyenne
			else {secuDigue <- 5.0;}
		}

		// distanceSea et distanceDigue influencent
		if (distanceSea() < 10) {secuDigue <- secuDigue-1;}
		if (distanceDigue() < 10) {secuDigue <- secuDigue +1 ;}


		// distance a la mer et présence digue
		valeurSecurite <- distanceSea+secuDigue; 
		  
		   
		// distance a la digue la plus proche (ou 15 si pas encore de digue)
		list<parcelle> parcellesVoisinesDigue <- neighbour_cells_far where (each.digue>0);
		if (!empty(parcellesVoisinesDigue where (each.digue=2))) {valeurSecurite <- valeurSecurite+7;}
		if (!empty(parcellesVoisinesDigue where (each.digue=1))) {valeurSecurite <- valeurSecurite+3;}
		
	

		//valeurSecurite <- max([0, min([10,round(information+secuDigue+densite_bati/10-nbSubmersion-maxHauteur+distanceSea()/2000)/6])]);
	}
	

	
	reflex updateEcolo {
		//if (hasDyke) {valeurEcolo <- valeurEcolo+8;}
		//if (hasBriseLame) {valeurEcolo <- valeurEcolo+4;}
		
		// self est-il dans les neighbours??

		list<parcelle> parcellesVoisinesDigue <- neighbour_cells_far where (each.digue>0);
	//	if (empty(parcellesVoisinesDigue)) {write "vide";}
		write length(neighbour_cells_far);
		write " tyt : " +length(parcellesVoisinesDigue);
		if (!empty(parcellesVoisinesDigue where (each.digue=2))) {valeurEcolo <- valeurEcolo-8;}
		if (!empty(parcellesVoisinesDigue where (each.digue=1))) {valeurEcolo <- valeurEcolo-4;}
	}

	reflex updateValeurPolitique when: !phase_sub
	{
	// a ete exproprie
	// est non constructible
	// pas d'action d'information

	}

	/*************************************
	 * 			ACTIONS DE LA PARCELLE 	 *
	 *************************************/
	 
	 //action de transmission de la submersion
	action flow
	{
		// s'il y a de l'eau sur la cellule, il faut la diffuser
		if (water_height > 0)
		{
			// trouver la liste des voisins deja traites pour la diffusion
			list<parcelle> neighbour_cells_al <- neighbour_cells where (each.already);
			// si cette liste n'est pas vide
			if (!empty(neighbour_cells_al))
			{
				// la hauteur de ces voisins devient egale a alt+water+obstacle
				ask neighbour_cells_al
				{
					height <- altitude + water_height + obstacle_height;
				}
				// la hauteur de la cellule vaut altitude + hauteur d'eau
				height <- altitude + water_height;
				// cellules cibles de la diffusion = celles de hauteur plus basse que la cellule courante
				list<parcelle> flow_cells <- (neighbour_cells_al where (height > each.height));
				// s'il y a des cellules plus basses
				if (!empty(flow_cells))
				{
					loop flow_cell over: shuffle(flow_cells) sort_by (each.height)
					{
						float water_flowing <- max([0.0, min([(height - flow_cell.height), water_height * diffusion_rate])]);
						water_height <- water_height - water_flowing;
						flow_cell.water_height <- flow_cell.water_height + water_flowing;
						height <- altitude + water_height;
					}
				}
			}
		}
		already <- true;
	}

	// mise a jour couleur en fonction de la hauteur d'eau
	// TODO: a remplacer par un aspect specifique pour visualisation de l'eau
	action update_color
	{
		int val_water <- 0;
		// valeur du degrade de bleu en fonction de la hauteur d'eau
		val_water <- max([0, min([255, int(255 * (1 - (water_height / 1.0)))])]);
		color <- rgb([val_water, val_water, 255]);
		//grid_value <- water_height + altitude;
	}

	action update_after_destruction (obstacle the_obstacle)
	{
		// retirer l'obstacle de la liste d'obstacles presents sur cette cellule
		remove the_obstacle from: obstacles;
		// et mettre a jour la hauteur totale d'obstacles (qui baisse en consequence)
		obstacle_height <- compute_highest_obstacle();
	}
	 
	 
	// diminuer le budget du territoire
	action decrement_budget {
		mon_territoire.budget <- mon_territoire.budget-1;
		write 'budget restant '+mon_territoire.budget;
	}


	/************************************
	 * *** ACTIONS DE L'UTILISATEUR *** *
	 * *** JEU INTERACTIF           *** *
	 ************************************/
	 
	action releveStatSubm {
		if water_height>0 {
			//write (water_height);
			eau_present<-true;
		}
		if water_height>maxHauteur {maxHauteur<-water_height;}  
	}
	

	 
	
	// construction de digue non ecolo (protection++, ecolo--)
	user_command "construire une digue en béton"
	{ 
		if (mon_territoire.budget>0) {
			create dyke
			{
				write "" + myself;
				est_ecolo <- false; // ecolooupas
				location <- myself.location;
				height<-6.0;
			}
			do decrement_budget;
		}
		else {
			write 'plus de budget, tour fini';
			phase_sub <- true;
		}	
		digue<-2;
		
	}
	
	// 
	user_command "construire un brise lame"
	{
		create dyke {
			est_ecolo <- true;
			location <- myself.location;
			height<-3.0;
		}
	digue<-1;
	}

	user_command "interdire construction" action: interdire_construction;
	action interdire_construction
	{
		constructible <- false;
		valeurPolitique <- valeurPolitique - 5;
	}

	action construire_maison
	{
		maison <- true;
	}

	// affichage graphique des parcelles
	aspect default
	{
	
	rgb ze_colour <- # white;
	// zone noire = rond noir
		if (!constructible)
		{
			draw circle(160 # m) color: # black;
		}

		// maison = carre bleu
		if (maison)
		{
			draw square(150 # m) color: rgb(255,255-255*densite_bati/100,255-255*densite_bati/100);
		}

		//digue = triangle jaune
		if (digue=1){
			draw triangle(100 # m) color : # yellow;
		}
		if (digue=2){
			draw triangle(100 # m) color : # orange;
		}
	}

	//*************** DEFINITION DES SORTIES***************

	// pour la carte de preservation ecologique des parcelles
	aspect ecolo
	{
		rgb ze_colour <- # white;
		if (is_sea)
		{
			ze_colour <- # blue;
		}
		// degrade de vert pour valeur ecolo
		else
		{
			ze_colour <- rgb(255 - 25.5 * valeurEcolo, 255, 255 - 25.5 * valeurEcolo);
		}

		draw square(self.shape.perimeter) color: ze_colour;
	}
	
	// pour la carte de la securite des parcelles
	aspect secur
	{
		rgb ze_colour <- # white;
		if (is_sea) {ze_colour <- # blue;}
		// degrade de rouge pour valeur secur
		else { ze_colour <- rgb(255, 255 - 25.5 * valeurSecurite, 255 - 25.5 * valeurSecurite); }
		draw square(self.shape.perimeter) color : ze_colour;
	}
	
		


}

/********************
 * *** SIMULATION ***
 ********************/
experiment Displays type: gui
{
//Definition de quelques parametres
	parameter "Phase de submersion ?: " var: phase_sub;
	output
	{
		//**********************CARTES***********************
		
		display map ambient_light: 100
		{
			grid parcelle triangulation : false lines : # black;
			species parcelle aspect: default;
			graphics "contour"
			{
				draw lamer.contour color : # yellow;
			}

		}

		// carte des valeurs ecolo
		display map_ecolo ambient_light: 100
		{
			grid parcelle triangulation: false lines: # black;
			species parcelle aspect: ecolo;
		}

		// carte des valeurs d'attractivite en jaune
		
		// carte de densite de population avec diametre du cercle dans la cellule
		
		// carte de securite en rouge
		display map_secu ambient_light: 100 
		{ 
			grid parcelle triangulation: false lines: # black ; 
			species parcelle aspect: secur ;
			species dyke;
		}


		//**********************GRAPHS***********************
	 	
	 	display HistoPopularite
		{
			chart "Cote de popularite du maire" type: series
			{
				data "nombre de satisfaits" value: (list(parcelle) count (each.valeurSatisfaction > 5)) color : °yellow;
				data "popularite" value: any(territoire).indicateurPopularite;
			}
		} 

		display HistoSecurite
		{
			chart "Niveau de securite du territoire" type: series
			{
				data "securite moyenne" value: any(territoire).indicateurSecuriteMoyenne color: °red;
				data "securite minimale" value: any(territoire).indicateurSecuriteMinimale color:#black;
			}
		}
		display HistoDommage
		{
			/*chart "Niveau de securite du territoire" type: series
			{
				data "Taux de dommage" value: dommageTotal color: °red;

			}*/
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
